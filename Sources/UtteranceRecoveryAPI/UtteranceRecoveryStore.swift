import Foundation
import VADAPI

/// Replaceable crash-recovery boundary between VAD and inference.
public protocol UtteranceRecoveryStore: Sendable {
    /// Persists audio and metadata before the caller may start inference.
    func stage(
        _ segment: SpeechSegment,
        for sessionID: UUID
    ) async throws -> PendingUtteranceRecord

    /// Reloads committed records and quarantines unreadable artifacts.
    func recoverPending(for sessionID: UUID) async throws -> UtteranceRecoveryBatch

    /// Discovers and reloads committed records left by every prior session.
    func recoverAllPending() async throws -> UtteranceRecoveryBatch

    /// Lazily reloads committed records in bounded, session-contiguous pages.
    func recoverAllPendingPages(
        maximumRecordsPerPage: Int
    ) async throws -> UtteranceRecoveryPages

    /// Removes a committed record only after all downstream work is durable.
    func markCompleted(_ id: PendingUtteranceID) async throws
}

extension UtteranceRecoveryStore {
    public func recoverAllPendingPages(
        maximumRecordsPerPage: Int
    ) async throws -> UtteranceRecoveryPages {
        guard maximumRecordsPerPage > 0 else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumRecordsPerPage")
        }
        let source = LegacyRecoveryPageSource(
            batch: try await recoverAllPending(),
            maximumRecordsPerPage: maximumRecordsPerPage
        )
        return UtteranceRecoveryPages {
            await source.next()
        }
    }
}
