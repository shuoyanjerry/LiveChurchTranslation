import Foundation
import UtteranceRecoveryAPI
import VADAPI

struct PendingMetadata: Codable, Sendable {
    static let unversionedSchemaVersion = 1
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let sessionID: UUID
    let segmentID: UUID
    let sequenceNumber: UInt64
    let sampleRate: Double
    let sampleCount: Int
    let wavFileBytes: Int
    let startedAt: StoredDuration
    let endedAt: StoredDuration
    let endReason: StoredEndReason
    let stagedAt: Date

    init(sessionID: UUID, segment: SpeechSegment, wavFileBytes: Int, stagedAt: Date) {
        schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID
        segmentID = segment.id
        sequenceNumber = segment.sequenceNumber
        sampleRate = segment.sampleRate
        sampleCount = segment.samples.count
        self.wavFileBytes = wavFileBytes
        startedAt = StoredDuration(segment.startedAt)
        endedAt = StoredDuration(segment.endedAt)
        endReason = StoredEndReason(segment.endReason)
        self.stagedAt = stagedAt
    }

    var id: PendingUtteranceID {
        PendingUtteranceID(
            sessionID: sessionID,
            segmentID: segmentID,
            sequenceNumber: sequenceNumber
        )
    }

    var processingTopology: UtteranceProcessingTopology {
        schemaVersion == Self.unversionedSchemaVersion
            ? .unversionedV1
            : .segmentEntry
    }

    func makeSegment(samples: [Float]) -> SpeechSegment {
        SpeechSegment(
            id: segmentID,
            sequenceNumber: sequenceNumber,
            samples: samples,
            sampleRate: sampleRate,
            startedAt: startedAt.duration,
            endedAt: endedAt.duration,
            endReason: endReason.value
        )
    }
}

struct StoredDuration: Codable, Sendable {
    let seconds: Int64
    let attoseconds: Int64

    init(_ duration: Duration) {
        let components = duration.components
        seconds = components.seconds
        attoseconds = components.attoseconds
    }

    var duration: Duration {
        Duration(secondsComponent: seconds, attosecondsComponent: attoseconds)
    }
}

enum StoredEndReason: String, Codable, Sendable {
    case trailingSilence
    case softSilence
    case maximumBoundary
    case maximumDuration
    case endOfStream

    init(_ value: SpeechSegmentEndReason) {
        switch value {
        case .trailingSilence: self = .trailingSilence
        case .softSilence: self = .softSilence
        case .maximumBoundary: self = .maximumBoundary
        case .maximumDuration: self = .maximumDuration
        case .endOfStream: self = .endOfStream
        }
    }

    var value: SpeechSegmentEndReason {
        switch self {
        case .trailingSilence: .trailingSilence
        case .softSilence: .softSilence
        case .maximumBoundary: .maximumBoundary
        case .maximumDuration: .maximumDuration
        case .endOfStream: .endOfStream
        }
    }
}
