import Foundation
import UtteranceRecoveryAPI

extension FileUtteranceRecoveryStore {
    public func recoverPending(for sessionID: UUID) async throws -> UtteranceRecoveryBatch {
        do {
            try prepareSessionDirectory(sessionID)
            return try sessionScanner().scan(sessionID: sessionID)
        } catch {
            throw fileSystemError("recoverPending", error)
        }
    }

    public func recoverAllPending() async throws -> UtteranceRecoveryBatch {
        do {
            return try RecoveryRootScanner(
                layout: layout,
                limits: limits,
                reader: recordReader(),
                writer: writer,
                fileManager: fileManager,
                now: now
            ).scan()
        } catch {
            throw fileSystemError("recoverAllPending", error)
        }
    }

    public func markCompleted(_ id: PendingUtteranceID) async throws {
        let record = layout.recordDirectory(id)
        guard fileManager.fileExists(atPath: record.path) else {
            throw UtteranceRecoveryError.recordNotFound(id)
        }
        let tombstone = layout.completionDirectory(id.sessionID)
        do {
            try fileManager.moveItem(at: record, to: tombstone)
            try writer.synchronizeDirectory(layout.pendingDirectory(id.sessionID))
            try fileManager.removeItem(at: tombstone)
            try writer.synchronizeDirectory(layout.pendingDirectory(id.sessionID))
        } catch {
            throw fileSystemError("markCompleted", error)
        }
    }

    func prepareSessionDirectory(_ sessionID: UUID) throws {
        try writer.createPrivateDirectory(layout.root)
        try writer.createPrivateDirectory(layout.sessionDirectory(sessionID))
        try writer.createPrivateDirectory(layout.pendingDirectory(sessionID))
    }

    private func recordReader() -> PendingRecordReader {
        PendingRecordReader(layout: layout, limits: limits, fileManager: fileManager)
    }

    private func sessionScanner() -> RecoveryScanner {
        RecoveryScanner(
            layout: layout,
            reader: recordReader(),
            writer: writer,
            fileManager: fileManager,
            limits: limits,
            now: now
        )
    }
}
