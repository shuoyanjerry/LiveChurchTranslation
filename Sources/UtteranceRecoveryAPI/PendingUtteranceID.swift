import Foundation

/// Stable identity for one durable VAD-to-inference handoff.
public struct PendingUtteranceID: Codable, Sendable, Equatable, Hashable {
    public let sessionID: UUID
    public let segmentID: UUID
    public let sequenceNumber: UInt64

    public init(sessionID: UUID, segmentID: UUID, sequenceNumber: UInt64) {
        self.sessionID = sessionID
        self.segmentID = segmentID
        self.sequenceNumber = sequenceNumber
    }
}
