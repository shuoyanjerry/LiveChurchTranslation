import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    public func recoverInterruptedSession(
        sessionID: UUID,
        finalization: TranscriptFinalization
    ) async throws -> InterruptedTranscriptRecoveryResult {
        guard !activeSessionIDs.contains(sessionID) else { return .skippedActive }
        guard !hasRecordingActivityArtifact(sessionID: sessionID) else {
            return .skippedActive
        }
        do {
            return try recoverInterruptedTranscript(
                sessionID: sessionID,
                finalization: finalization
            )
        } catch let error as TranscriptStoreError {
            throw error
        } catch {
            throw TranscriptStoreError.fileSystem(
                "会议 \(sessionID.uuidString) 的中断听抄稿恢复失败："
                    + error.localizedDescription
            )
        }
    }

    private func recoverInterruptedTranscript(
        sessionID: UUID,
        finalization: TranscriptFinalization
    ) throws -> InterruptedTranscriptRecoveryResult {
        let manifest = try validatedRecoveryManifest(sessionID: sessionID)
        guard manifest.requiresInterruptionRecovery else { return .notRequired }
        let entries = try readRecoveryEntries(sessionID: sessionID)
        let endedAt = try recoveredEndDate(manifest: manifest, entries: entries)
        let recovered = recoveredSession(manifest: manifest, entries: entries, endedAt: endedAt)
        let recoveredFinalization = interruptionFinalization(from: finalization)
        try persistRecoveredSession(recovered, finalization: recoveredFinalization)
        entryIDs[sessionID] = Set(entries.map(\.id))
        return .recovered(
            RecoveredTranscriptSession(
                sessionID: sessionID,
                endedAt: endedAt,
                entryCount: entries.count
            )
        )
    }

    private func validatedRecoveryManifest(sessionID: UUID) throws -> SessionManifest {
        let directory = sessionDirectory(sessionID)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw TranscriptStoreError.sessionNotFound
        }
        guard try isSafeSessionDirectory(directory) else {
            throw TranscriptStoreError.invalidSessionDirectory
        }
        let manifest = try recoveryManifest(sessionID: sessionID)
        guard manifest.id == sessionID else {
            throw TranscriptStoreError.invalidSessionDirectory
        }
        return manifest
    }

    private func recoveredSession(
        manifest: SessionManifest,
        entries: [TranscriptEntry],
        endedAt: Date
    ) -> TranscriptSession {
        TranscriptSession(
            id: manifest.id,
            startedAt: manifest.startedAt,
            endedAt: endedAt,
            entries: entries.sorted { $0.sequence < $1.sequence },
            title: manifest.title,
            kind: manifest.kind,
            sourceLanguage: manifest.sourceLanguage,
            targetLanguage: manifest.targetLanguage
        )
    }

    private func interruptionFinalization(
        from finalization: TranscriptFinalization
    ) -> TranscriptFinalization {
        TranscriptFinalization(
            kind: .recoveredAfterInterruption,
            pendingRecordCount: finalization.pendingRecordCount,
            rejections: finalization.rejections,
            quarantinedArtifactCount: finalization.quarantinedArtifactCount,
            hasUnrecoverableFailure: finalization.hasUnrecoverableFailure
        )
    }

    private func persistRecoveredSession(
        _ session: TranscriptSession,
        finalization: TranscriptFinalization
    ) throws {
        try completeMarkdown(for: session, finalization: finalization).write(
            to: markdownURL(session.id),
            atomically: true,
            encoding: .utf8
        )
        try writeManifest(for: session, finalization: finalization)
        try enforcePrivatePermissions(sessionID: session.id)
    }
}
