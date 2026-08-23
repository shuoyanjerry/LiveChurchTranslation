import Foundation
import VADAPI

/// Replaceable crash-recovery boundary between VAD and inference.
public protocol SessionRecoveryArtifactDeleting: Sendable {
    func deleteArtifacts(for sessionID: UUID) async throws
}

public protocol UtteranceRecoveryStore: SessionRecoveryArtifactDeleting, Sendable {
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

    /// Reports durable work and terminal audit evidence for one session.
    func summary(for sessionID: UUID) async throws -> UtteranceRecoverySessionSummary

    /// Atomically moves a record out of the retry queue after reaching a durable outcome.
    func resolve(
        _ id: PendingUtteranceID,
        as resolution: UtteranceRecoveryResolution
    ) async throws

}

extension UtteranceRecoveryStore {
    /// Compatibility spelling for the successful terminal outcome.
    public func markCompleted(_ id: PendingUtteranceID) async throws {
        try await resolve(id, as: .completed)
    }

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
