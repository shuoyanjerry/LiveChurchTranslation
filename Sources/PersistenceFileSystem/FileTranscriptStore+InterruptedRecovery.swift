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
            guard manifest.requiresInterruptionRecovery else { return .notRequired }

            let entries = try readRecoveryEntries(sessionID: sessionID)
            let endedAt = try recoveredEndDate(manifest: manifest, entries: entries)
            let recovered = TranscriptSession(
                id: manifest.id,
                startedAt: manifest.startedAt,
                endedAt: endedAt,
                entries: entries.sorted { $0.sequence < $1.sequence },
                title: manifest.title,
                kind: manifest.kind,
                sourceLanguage: manifest.sourceLanguage,
                targetLanguage: manifest.targetLanguage
            )

            let recoveredFinalization = TranscriptFinalization(
                kind: .recoveredAfterInterruption,
                pendingRecordCount: finalization.pendingRecordCount,
                rejections: finalization.rejections,
                quarantinedArtifactCount: finalization.quarantinedArtifactCount,
                hasUnrecoverableFailure: finalization.hasUnrecoverableFailure
            )
            try completeMarkdown(
                for: recovered,
                finalization: recoveredFinalization
            ).write(
                to: markdownURL(sessionID),
                atomically: true,
                encoding: .utf8
            )
            try writeManifest(for: recovered, finalization: recoveredFinalization)
            try enforcePrivatePermissions(sessionID: sessionID)
            entryIDs[sessionID] = Set(entries.map(\.id))
            return .recovered(
                RecoveredTranscriptSession(
                    sessionID: sessionID,
                    endedAt: endedAt,
                    entryCount: entries.count
                )
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
}
