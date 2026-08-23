public struct TranslationQualificationAttempt: Codable, Equatable, Sendable {
    public let segmentID: String
    public let sourceID: String
    public let sequence: Int
    public let status: TranslationQualificationAttemptStatus
    public let originalChinese: String
    public let observedASRText: String
    public let translationSourceText: String
    public let hypothesisEnglish: String?
    public let humanReferenceEnglish: String
    public let referenceProfileID: String
    public let semanticReviewEligible: Bool
    public let exactStringMetricEligible: Bool
    public let contextSegmentIDs: [String]
    public let strictRetryUsed: Bool
    public let completionAttemptCount: Int
    public let completionOutcomes: [String]
    public let latencySeconds: Double
    public let failureCode: String?
    public let glossaryTerms: [TranslationQualificationTermResult]
    public let preservationChecks: [TranslationQualificationCheck]
    public let pronounResults: [TranslationQualificationPronounResult]

    public init(
        segment: TranslationQualificationSegment,
        status: TranslationQualificationAttemptStatus,
        hypothesisEnglish: String?,
        translationSourceText: String,
        contextSegmentIDs: [String],
        strictRetryUsed: Bool,
        completionAttemptCount: Int,
        completionOutcomes: [String],
        latencySeconds: Double,
        failureCode: String?,
        glossaryTerms: [TranslationQualificationTermResult],
        preservationChecks: [TranslationQualificationCheck],
        pronounResults: [TranslationQualificationPronounResult]
    ) {
        segmentID = segment.id
        sourceID = segment.sourceID
        sequence = segment.sequence
        self.status = status
        originalChinese = segment.originalChinese
        observedASRText = segment.observedASRAmbiguousChinese
        self.translationSourceText = translationSourceText
        self.hypothesisEnglish = hypothesisEnglish
        humanReferenceEnglish = segment.referenceEnglish
        referenceProfileID = segment.referenceProfileID
        semanticReviewEligible = segment.qualification.semanticScoringEligible
        exactStringMetricEligible = segment.qualification.exactStringScoringEligible
        self.contextSegmentIDs = contextSegmentIDs
        self.strictRetryUsed = strictRetryUsed
        self.completionAttemptCount = completionAttemptCount
        self.completionOutcomes = completionOutcomes
        self.latencySeconds = latencySeconds
        self.failureCode = failureCode
        self.glossaryTerms = glossaryTerms
        self.preservationChecks = preservationChecks
        self.pronounResults = pronounResults
    }
}

public struct TranslationQualificationLatency: Codable, Equatable, Sendable {
    public let minimumSeconds: Double
    public let medianSeconds: Double
    public let p95Seconds: Double
    public let maximumSeconds: Double
}

public struct TranslationQualificationAggregate: Codable, Equatable, Sendable {
    public let attemptCount: Int
    public let successCount: Int
    public let failureCount: Int
    public let strictRetryCount: Int
    public let latency: TranslationQualificationLatency
    public let checkPassCount: Int
    public let checkFailCount: Int
    public let humanReviewRequiredCount: Int
}

public struct TranslationQualificationReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: String
    public let corpusID: String
    public let manifestSHA256: String
    public let schemaSHA256: String
    public let provider: TranslationQualificationProvider
    public let environment: TranslationQualificationEnvironment
    /// Absent only when decoding a historical schema-v1 diagnostic artifact.
    public let executionProvenance: TranslationExecutionProvenance?
    public let metricPolicy: [String]
    public let attempts: [TranslationQualificationAttempt]
    public let aggregate: TranslationQualificationAggregate
}
