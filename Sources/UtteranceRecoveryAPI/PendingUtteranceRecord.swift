import Foundation
import VADAPI

/// Immutable speech segment staged durably before inference starts.
public struct PendingUtteranceRecord: Sendable, Equatable {
    public let id: PendingUtteranceID
    public let segment: SpeechSegment
    public let stagedAt: Date

    public init(id: PendingUtteranceID, segment: SpeechSegment, stagedAt: Date) {
        self.id = id
        self.segment = segment
        self.stagedAt = stagedAt
    }
}
