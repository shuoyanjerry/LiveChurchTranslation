struct DiscourseQualificationRate: Codable, Equatable, Sendable {
    let numeratorCount: Int
    let denominatorCount: Int
    let basisPoints: Int

    init(numerator: Int, denominator: Int) {
        numeratorCount = numerator
        denominatorCount = denominator
        basisPoints = denominator == 0 ? 0 : numerator * 10_000 / denominator
    }
}

struct DiscourseQualificationMetrics: Codable, Equatable, Sendable {
    let segmentCount: Int
    let occurrenceCount: Int
    let exactPolicyMatchCount: Int
    let policyMismatchCount: Int
    let resolvableOccurrenceCount: Int
    let correctAutomaticResolutionCount: Int
    let missedResolvableCount: Int
    let expectedAbstentionCount: Int
    let safeAbstentionCount: Int
    let protectedOccurrenceCount: Int
    let safeProtectionCount: Int
    let wrongAutomaticResolutionCount: Int
    let mappingFailureCount: Int
    let unmappedGuidanceCount: Int
    let resolutionCoverage: DiscourseQualificationRate
    let abstentionSafety: DiscourseQualificationRate
    let hardFailureCount: Int
}

struct DiscourseQualificationSourceMetrics: Codable, Equatable, Sendable {
    let sourceID: String
    let metrics: DiscourseQualificationMetrics
}

struct DiscourseQualificationReport: Codable, Sendable {
    let schemaVersion: Int
    let corpusID: String
    let manifestSHA256: String
    let schemaSHA256: String
    let resolver: DiscourseQualificationResolverMetadata
    let aggregate: DiscourseQualificationMetrics
    let sources: [DiscourseQualificationSourceMetrics]
    let segments: [DiscourseQualificationSegmentReport]
}
