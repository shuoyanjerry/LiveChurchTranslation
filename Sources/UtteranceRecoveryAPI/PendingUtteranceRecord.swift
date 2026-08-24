import Foundation
import VADAPI

public enum UtteranceProcessingTopology: Equatable, Sendable {
    /// Schema v1 predates an explicit topology marker. Recovery must resolve
    /// atomic-versus-split behavior from durable entries without guessing.
    case unversionedV1
    /// One finalized VAD segment produces one translation and transcript entry.
    case segmentEntry
}

/// Immutable speech segment staged durably before inference starts.
public struct PendingUtteranceRecord: Sendable, Equatable {
    public let id: PendingUtteranceID
    public let segment: SpeechSegment
    public let stagedAt: Date
    public let processingTopology: UtteranceProcessingTopology

    public init(
        id: PendingUtteranceID,
        segment: SpeechSegment,
        stagedAt: Date,
        processingTopology: UtteranceProcessingTopology = .segmentEntry
    ) {
        self.id = id
        self.segment = segment
        self.stagedAt = stagedAt
        self.processingTopology = processingTopology
    }
}
