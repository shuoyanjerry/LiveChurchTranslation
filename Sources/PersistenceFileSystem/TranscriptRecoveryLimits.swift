import Foundation

public struct TranscriptRecoveryLimits: Equatable, Sendable {
    public let maximumDirectoryEntries: Int
    public let maximumCandidateSessions: Int
    public let maximumTranscriptBytes: Int
    public let maximumEntriesPerSession: Int

    public init(
        maximumDirectoryEntries: Int = 2_048,
        maximumCandidateSessions: Int = 512,
        maximumTranscriptBytes: Int = 128 * 1_024 * 1_024,
        maximumEntriesPerSession: Int = 100_000
    ) {
        self.maximumDirectoryEntries = min(max(1, maximumDirectoryEntries), 8_192)
        self.maximumCandidateSessions = min(max(1, maximumCandidateSessions), 1_024)
        self.maximumTranscriptBytes = min(
            max(1, maximumTranscriptBytes),
            256 * 1_024 * 1_024
        )
        self.maximumEntriesPerSession = min(max(1, maximumEntriesPerSession), 250_000)
    }
}
