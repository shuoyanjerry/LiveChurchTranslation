import Foundation

enum V3SelectedVADSceneClass: String, Codable, CaseIterable, Sendable {
    case genuineChurchSermon = "genuine_church_sermon"
    case scriptedOrNarrationProgram = "scripted_or_narration_program"
}

struct V3SelectedVADTrackMetrics: Codable, Equatable, Sendable {
    let productionVoiceSignatureSHA256: String
    let shadowVoiceSignatureSHA256: String
    let productionShadowParity: Bool
    let speechStartedCount: Int
    let segmentCount: Int
    let underTwoSecondsCount: Int
    let reasonCounts: [String: Int]
    let segmentDurationSamples: [Int]
    let candidateReachedCounts: [String: Int]
    let candidateResolutionCounts: [String: Int]
}

struct V3SelectedVADAttempt: Codable, Equatable, Sendable {
    let logicalItemOrdinal: Int
    let trackOrdinal: Int
    let sceneClass: V3SelectedVADSceneClass
    let sourceWAVSHA256: String
    let sourceWAVByteCount: Int64
    let exactSampleFrames: Int64
    let audioSeconds: Double
    let resetBeforeTrack: Bool
    let endOfStreamAfterTrack: Bool
    let success: Bool
    let failureCode: V3SelectedVADFailureCode?
    let metrics: V3SelectedVADTrackMetrics?
}

struct V3SelectedVADMetricAggregate: Codable, Equatable, Sendable {
    let logicalItemCount: Int
    let trackAttemptCount: Int
    let successCount: Int
    let failureCount: Int
    let expectedSampleFrames: Int64
    let expectedAudioSeconds: Double
    let successfulSampleFrames: Int64
    let segmentCount: Int
    let underTwoSecondsCount: Int
    let forcedHardCutProxyCount: Int
    let reasonCounts: [String: Int]
    let failureCodeCounts: [String: Int]
    let segmentDurationSamplesP50: Int?
    let segmentDurationSamplesP95: Int?
    let segmentDurationSamplesP99: Int?
    let candidateReachedCounts: [String: Int]
    let candidateResolutionCounts: [String: Int]
    let parityPassCount: Int
}

struct V3SelectedVADAggregates: Codable, Equatable, Sendable {
    let overall: V3SelectedVADMetricAggregate
    let genuineChurchSermons: V3SelectedVADMetricAggregate
    let scriptedOrNarrationPrograms: V3SelectedVADMetricAggregate
}
