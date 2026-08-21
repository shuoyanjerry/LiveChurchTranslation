import Foundation

/// Why a VAD implementation closed a speech segment.
public enum SpeechSegmentEndReason: Sendable, Equatable {
    case trailingSilence
    case maximumDuration
    case endOfStream
}

/// Immutable speech audio passed from VAD to an ASR provider.
public struct SpeechSegment: Sendable, Equatable {
    public let id: UUID
    public let sequenceNumber: UInt64
    public let samples: [Float]
    public let sampleRate: Double
    public let startedAt: Duration
    public let endedAt: Duration
    public let endReason: SpeechSegmentEndReason

    public init(
        id: UUID = UUID(),
        sequenceNumber: UInt64,
        samples: [Float],
        sampleRate: Double,
        startedAt: Duration,
        endedAt: Duration,
        endReason: SpeechSegmentEndReason
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.samples = samples
        self.sampleRate = sampleRate
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
    }

    public var duration: Duration {
        endedAt - startedAt
    }
}
