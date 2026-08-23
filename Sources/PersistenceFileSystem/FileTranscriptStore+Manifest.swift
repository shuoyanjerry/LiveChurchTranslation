import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    func enforcePrivatePermissions(sessionID: UUID) throws {
        for directory in [root, sessionDirectory(sessionID)] {
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: directory.path
            )
        }
        for file in [manifestURL(sessionID), jsonLinesURL(sessionID), markdownURL(sessionID)]
        where fileManager.fileExists(atPath: file.path) {
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: file.path
            )
        }
    }

    func writeManifest(
        for session: TranscriptSession,
        integrity: StoredTranscriptIntegrity
    ) throws {
        try writeManifest(for: session, integrity: integrity, finalization: .complete)
    }

    func writeManifest(
        for session: TranscriptSession,
        finalization: TranscriptFinalization
    ) throws {
        try writeManifest(
            for: session,
            integrity: finalization.integrity,
            finalization: finalization
        )
    }

    private func writeManifest(
        for session: TranscriptSession,
        integrity: StoredTranscriptIntegrity,
        finalization: TranscriptFinalization
    ) throws {
        let manifest = SessionManifest(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            entryCount: session.entries.count,
            title: session.title,
            kind: session.kind,
            sourceLanguage: session.sourceLanguage,
            targetLanguage: session.targetLanguage,
            integrity: integrity,
            pendingRecordCount: finalization.pendingRecordCount,
            rejections: finalization.rejections,
            quarantinedArtifactCount: finalization.quarantinedArtifactCount,
            hasUnrecoverableFailure: finalization.hasUnrecoverableFailure
        )
        try jsonEncoder.encode(manifest).write(to: manifestURL(session.id), options: .atomic)
    }

    func readSummary(_ directory: URL) throws -> StoredSessionSummary? {
        let url = directory.appending(path: "session.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let manifest = try decoder().decode(SessionManifest.self, from: Data(contentsOf: url))
        return StoredSessionSummary(
            id: manifest.id,
            startedAt: manifest.startedAt,
            endedAt: manifest.endedAt,
            entryCount: manifest.entryCount,
            location: directory,
            title: manifest.title,
            kind: manifest.kind,
            sourceLanguage: manifest.sourceLanguage,
            targetLanguage: manifest.targetLanguage,
            integrity: manifest.integrity,
            pendingRecordCount: manifest.pendingRecordCount,
            rejectedSentenceCount: manifest.rejections.count,
            quarantinedArtifactCount: manifest.quarantinedArtifactCount
        )
    }

    func mergedFinalization(
        sessionID: UUID,
        current: TranscriptFinalization
    ) throws -> TranscriptFinalization {
        guard fileManager.fileExists(atPath: manifestURL(sessionID).path) else {
            throw TranscriptStoreError.sessionNotFound
        }
        let manifest = try decoder().decode(
            SessionManifest.self,
            from: Data(contentsOf: manifestURL(sessionID), options: [.mappedIfSafe])
        )
        guard manifest.id == sessionID else {
            throw TranscriptStoreError.invalidSessionDirectory
        }
        let historical = manifest.finalization
        let rejections = Set(historical.rejections).union(current.rejections)
            .sorted(by: StoredTranscriptRejection.stableOrder)
        return TranscriptFinalization(
            kind: current.kind,
            pendingRecordCount: current.pendingRecordCount,
            rejections: rejections,
            quarantinedArtifactCount: max(
                historical.quarantinedArtifactCount,
                current.quarantinedArtifactCount
            ),
            hasUnrecoverableFailure: historical.hasUnrecoverableFailure
                || current.hasUnrecoverableFailure
        )
    }
}

extension StoredTranscriptRejection {
    fileprivate static func stableOrder(
        _ left: StoredTranscriptRejection,
        _ right: StoredTranscriptRejection
    ) -> Bool {
        if left.sentenceID != right.sentenceID {
            return left.sentenceID.uuidString < right.sentenceID.uuidString
        }
        if left.sentenceOrdinal != right.sentenceOrdinal {
            return left.sentenceOrdinal < right.sentenceOrdinal
        }
        if left.stage != right.stage { return left.stage < right.stage }
        return left.failureCode < right.failureCode
    }
}
