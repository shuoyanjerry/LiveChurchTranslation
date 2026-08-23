import Foundation

public struct ASRQualificationTimingSummaryV3: Codable, Equatable, Hashable, Sendable {
    public let attemptCount: Int
    public let successCount: Int
    public let failureCount: Int
    public let successfulAttemptLatencyP50Seconds: Double?
    public let successfulAttemptLatencyP95Seconds: Double?
    public let allAttemptLatencyP50Seconds: Double
    public let allAttemptLatencyP95Seconds: Double
    public let withinThreeSecondsRate: Double
    public let decodeSeconds: Double
    public let realTimeFactor: Double
}

public struct ASRQualificationClipReportV3: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let referenceText: String
    public let hypothesisText: String
    public let allowsHypothesisEdgeInsertions: Bool
    public let sourceAudioSeconds: Double
    public let decodedInputSeconds: Double
    public let unionCoveredSourceSeconds: Double
    public let attempts: [ASRQualificationAttemptV3]
    public let strictCER: ASRCharacterErrorMeasurement
    public let edgeFreeSemiglobalCER: ASRCharacterErrorMeasurement?
    public let strictPronounConfusion: ASRPronounConfusion
    public let timing: ASRQualificationTimingSummaryV3
}

public struct ASRQualificationAggregateReportV3: Codable, Equatable, Hashable, Sendable {
    public let clipCount: Int
    public let sourceAudioSeconds: Double
    public let decodedInputSeconds: Double
    public let unionCoveredSourceSeconds: Double
    public let strictCER: ASRCharacterErrorMeasurement
    public let edgeFreeSemiglobalCER: ASRCharacterErrorMeasurement?
    public let strictPronounConfusion: ASRPronounConfusion
    public let timing: ASRQualificationTimingSummaryV3
}

/// Provider-neutral, reproducible ASR qualification report schema V3.
public struct ASRQualificationReportV3: Codable, Equatable, Hashable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let corpusID: String
    public let qualificationManifestSHA256: String
    public let provider: ASRQualificationProviderMetadataV3
    public let environment: ASRQualificationEnvironmentV3
    public let clips: [ASRQualificationClipReportV3]
    public let aggregate: ASRQualificationAggregateReportV3
}
