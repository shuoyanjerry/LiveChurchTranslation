import Foundation

struct CandidatePauseBenchmarkDocument: Encodable {
    let schemaVersion = 2
    let mode = "shadowOnly"
    let decisionAuthority = "none"
    let sourceStrategy = VADBenchmarkStrategy.webrtcStable.rawValue
    let frameSampleCount: Int
    let sampleRateHz: Int
    let provenance: CandidatePauseProvenance
    let runtimeCaveats: [String]
    let files: [CandidatePauseFileReport]
    let aggregate: CandidatePauseAggregate
}

struct CandidatePauseProvenance: Encodable, Equatable {
    let sourceReportSHA256: String
    let sourceReportByteCount: Int64
    let selectedConfigurationSHA256: String
    let productionVADSourceSHA256: String
    let productionVADSourceFileCount: Int
    let companionSourceSHA256: String
    let companionSourceFileCount: Int
}

struct CandidatePauseFileReport: Encodable {
    let clipID: String
    let sourceWAVSHA256: String
    let sourceWAVByteCount: Int64
    let totalSamples: Int64
    let audioSeconds: Double
    let sourceBoundaryCount: Int
    let sourceEOFPaddingSamples: Int
    let sourceEOFLagCount: Int
    let finalizedBoundaries: [CandidatePauseFinalizedBoundary]
    let events: [CandidatePauseEventRecord]

    private enum CodingKeys: String, CodingKey {
        case clipID, sourceWAVSHA256, sourceWAVByteCount, totalSamples, audioSeconds
        case sourceBoundaryCount, finalizedBoundaries, events
        case sourceEOFPaddingSamples = "sourceEndOfStreamPaddingReconciledSamples"
        case sourceEOFLagCount = "sourceEndOfStreamEmissionLagReconciledCount"
    }
}

struct CandidatePauseEventRecord: Encodable, Equatable {
    let ordinal: Int
    let kind: String
    let sequenceNumber: UInt64
    let episodeNumber: UInt64
    let observedAtSourceSample: Int64
    let observedAtSeconds: Double
    let emittedAfterSourceSample: Int64
    let reached: CandidatePauseReachedRecord?
    let resolution: CandidatePauseResolutionRecord
    let finalizedBoundary: CandidatePauseFinalizedBoundary
}

struct CandidatePauseReachedRecord: Encodable, Equatable {
    let thresholdMilliseconds: Int
    let thresholdSampleCount: Int64
    let candidateEndSourceSample: Int64
    let candidateEndSeconds: Double
    let observationStartSourceSample: Int64
    let observationEndSourceSample: Int64
    let observationEndSeconds: Double
    let overshootSampleCount: Int64
}

struct CandidatePauseResolutionRecord: Encodable, Equatable {
    let kind: String
    let observedAtSourceSample: Int64
    let observedAtSeconds: Double
    let segmentEndReason: String?
}

struct CandidatePauseFinalizedBoundary: Encodable, Equatable {
    let sequenceNumber: UInt64
    let startSample: Int
    let endSample: Int
    let validSampleCount: Int
    let pcmSHA256: String
    let startedAtSeconds: Double
    let endedAtSeconds: Double
    let reason: String
}

struct CandidatePauseAggregate: Encodable, Equatable {
    let fileCount: Int
    let audioSeconds: Double
    let finalizedBoundaryCount: Int
    let sourceEOFPaddingSamples: Int
    let sourceEOFLagCount: Int
    let eventCount: Int
    let reachedCount: Int
    let resolvedCount: Int
    let episodeCount: Int
    let resolutionCounts: [String: Int]
    let finalEndReasonCounts: [String: Int]
    let thresholds: [CandidatePauseThresholdAggregate]

    private enum CodingKeys: String, CodingKey {
        case fileCount, audioSeconds, finalizedBoundaryCount, eventCount
        case reachedCount, resolvedCount, episodeCount, resolutionCounts
        case finalEndReasonCounts, thresholds
        case sourceEOFPaddingSamples = "sourceEndOfStreamPaddingReconciledSamples"
        case sourceEOFLagCount = "sourceEndOfStreamEmissionLagReconciledCount"
    }
}

struct CandidatePauseThresholdAggregate: Encodable, Equatable {
    let thresholdMilliseconds: Int
    let reachedCount: Int
    let resolutionCounts: [String: Int]
    let finalEndReasonCounts: [String: Int]
}

enum CandidatePauseBenchmarkError: Error, Equatable {
    case invalidSourceReport(String)
    case invalidTrace(String)
    case unsafeOutput
    case storageFailure
}
