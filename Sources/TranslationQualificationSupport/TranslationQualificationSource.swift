public struct TranslationQualificationSource: Decodable, Sendable {
    public let id: String
    public let provider: String
    public let titleChinese: String
    public let titleEnglish: String
    public let speaker: String
    public let sourcePageURL: String
    public let referenceURL: String
    public let audioURL: String
    public let audioLocalPath: String
    public let audioSHA256: String
    public let audioAlignment: String
    public let referenceLocalPath: String
    public let referenceSHA256: String
    public let extractedTextLocalPath: String
    public let extractedTextSHA256: String
    public let pageCount: Int
    public let pairCount: Int
    public let referenceProfileID: String
    public let rights: TranslationQualificationRights
}

public struct TranslationQualificationRights: Decodable, Sendable {
    public let classification: String
    public let evidenceURL: String
    public let localPrivateQAAllowed: Bool
    public let trainingAllowed: Bool
    public let redistributionAllowed: Bool
    public let mustNotCommit: Bool
}

public struct TranslationQualificationSummary: Decodable, Sendable {
    public let sourceCount: Int
    public let segmentPairCount: Int
    public let contentPairCount: Int
    public let headingOrTitlePairCount: Int
    public let sourcePairCounts: [TranslationQualificationCount]
    public let featureTagCounts: [TranslationQualificationCount]
    public let taGlyphOccurrenceCount: Int
    public let pronounGuidanceCounts: [TranslationQualificationCount]
    public let grnCandidateCount: Int
    public let hesedExcludedCount: Int
}

public struct TranslationQualificationCount: Decodable, Sendable {
    public let sourceID: String?
    public let tag: String?
    public let guidance: String?
    public let count: Int
}
