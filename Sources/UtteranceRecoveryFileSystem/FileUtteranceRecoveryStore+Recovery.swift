import Foundation
import UtteranceRecoveryAPI

extension FileUtteranceRecoveryStore {
    public func recoverPending(for sessionID: UUID) async throws -> UtteranceRecoveryBatch {
        do {
            guard fileManager.fileExists(atPath: layout.sessionDirectory(sessionID).path) else {
                return UtteranceRecoveryBatch(pending: [], quarantined: [])
            }
            return try sessionScanner().scan(sessionID: sessionID)
        } catch {
            throw fileSystemError("recoverPending", error)
        }
    }

    public func recoverAllPending() async throws -> UtteranceRecoveryBatch {
        do {
            return try rootScanner().scan()
        } catch {
            throw fileSystemError("recoverAllPending", error)
        }
    }

    public func recoverAllPendingPages(
        maximumRecordsPerPage: Int
    ) async throws -> UtteranceRecoveryPages {
        guard maximumRecordsPerPage > 0 else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumRecordsPerPage")
        }
        do {
            let cursor = FileRecoveryPageCursor(
                index: try rootScanner().index(),
                maximumRecordsPerPage: maximumRecordsPerPage
            )
            return UtteranceRecoveryPages {
                do {
                    return try await self.loadNextRecoveryPage(from: cursor)
                } catch let error as UtteranceRecoveryError {
                    throw error
                } catch {
                    throw UtteranceRecoveryError.fileSystem(
                        operation: "recoverAllPendingPages",
                        reason: error.localizedDescription
                    )
                }
            }
        } catch {
            throw fileSystemError("recoverAllPendingPages", error)
        }
    }

    private func loadNextRecoveryPage(
        from cursor: FileRecoveryPageCursor
    ) async throws -> UtteranceRecoveryBatch? {
        guard let slice = await cursor.next() else { return nil }
        var pending: [PendingUtteranceRecord] = []
        var quarantined = slice.quarantined
        for descriptor in slice.records {
            switch try sessionScanner().load(
                descriptor,
                sessionID: descriptor.id.sessionID
            ) {
            case .pending(let record): pending.append(record)
            case .quarantined(let artifact): quarantined.append(artifact)
            }
        }
        return UtteranceRecoveryBatch(pending: pending, quarantined: quarantined)
    }

    func prepareSessionDirectory(_ sessionID: UUID) throws {
        try writer.createPrivateDirectory(layout.root)
        try writer.createPrivateDirectory(layout.sessionDirectory(sessionID))
        try writer.createPrivateDirectory(layout.pendingDirectory(sessionID))
    }

    private func recordReader() -> PendingRecordReader {
        PendingRecordReader(layout: layout, limits: limits, fileManager: fileManager)
    }

    func sessionScanner() -> RecoveryScanner {
        RecoveryScanner(
            layout: layout,
            reader: recordReader(),
            writer: writer,
            fileManager: fileManager,
            limits: limits,
            now: now
        )
    }

    private func rootScanner() -> RecoveryRootScanner {
        RecoveryRootScanner(
            layout: layout,
            limits: limits,
            reader: recordReader(),
            writer: writer,
            fileManager: fileManager,
            now: now
        )
    }
}
