public struct TranslationQualificationManifest: Decodable, Sendable {
    public let schemaVersion: Int
    public let schemaPath: String
    public let corpusID: String
    public let generatedAt: String
    public let visibility: String
    public let provenance: TranslationQualificationProvenance
    public let policy: TranslationQualificationPolicy
    public let referenceProfiles: [TranslationQualificationReferenceProfile]
    public let sources: [TranslationQualificationSource]
    public let segments: [TranslationQualificationSegment]
    public let candidateSources: [TranslationQualificationCandidateSource]
    public let summary: TranslationQualificationSummary
}

public struct TranslationQualificationProvenance: Decodable, Sendable {
    public let parentCorpusManifestPath: String
    public let parentCorpusManifestSHA256: String
    public let searchProvider: String
    public let sourcesReviewedInParentResearch: Int
    public let latestExtensionStatus: String
    public let builderSHA256: String
    public let configSHA256: String
    public let candidateConfigSHA256: String
    public let supportSHA256: String
}

public struct TranslationQualificationPolicy: Decodable, Sendable {
    public let taDegradation: String
    public let genderRule: String
    public let referenceRule: String
    public let copyrightRule: String
}

public struct TranslationQualificationReferenceProfile: Decodable, Sendable {
    public let id: String
    public let spokenTextClass: String
    public let spokenAudioVerification: String
    public let translationClass: String
    public let exactStringMetricEligible: Bool
    public let allowedQualification: [String]
    public let forbiddenQualification: [String]
    public let knownLimitations: [String]
}

public struct TranslationQualificationCandidateSource: Decodable, Sendable {
    public let id: String
    public let provider: String
    public let localFiles: [TranslationQualificationLocalFile]?
}

public struct TranslationQualificationLocalFile: Decodable, Sendable {
    public let path: String
    public let sha256: String
}
