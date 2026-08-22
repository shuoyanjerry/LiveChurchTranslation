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

    /// Removes a committed record only after all downstream work is durable.
    func markCompleted(_ id: PendingUtteranceID) async throws
}
