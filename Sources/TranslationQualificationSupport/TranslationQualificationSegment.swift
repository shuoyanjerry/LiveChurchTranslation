public struct TranslationQualificationSegment: Decodable, Sendable {
    public let id: String
    public let sourceID: String
    public let sequence: Int
    public let unitKind: String
    public let referenceProfileID: String
    public let discourseContextIDs: [String]
    public let locator: TranslationQualificationLocator
    public let originalChinese: String
    public let observedASRAmbiguousChinese: String
    public let referenceEnglish: String
    public let featureTags: [String]
    public let theologyTerms: [String]
    public let pronounOccurrences: [TranslationPronounOccurrence]
    public let referenceWarnings: [String]
    public let qualification: TranslationQualificationEligibility
}

public struct TranslationQualificationLocator: Decodable, Sendable {
    public let chinesePages: [Int]
    public let englishPages: [Int]
}

public struct TranslationQualificationEligibility: Decodable, Sendable {
    public let semanticScoringEligible: Bool
    public let exactStringScoringEligible: Bool
    public let asrCEREligible: Bool
    public let requiresHumanSemanticReview: Bool
}

public enum TranslationExpectedPronounGuidance: String, Codable, Equatable, Sendable {
    case verifiedMale
    case verifiedFemale
    case deity
    case unresolved
    case pluralNeutral
    case lexicalNotPronoun
}

public enum TranslationPronounTokenClass: String, Codable, Equatable, Sendable {
    case singularPronoun
    case pluralPronoun
    case lexicalOtherPeople
}

public struct TranslationPronounOccurrence: Decodable, Sendable {
    public let id: String
    public let unicodeScalarOffset: Int
    public let originalGlyph: String
    public let observedGlyph: String
    public let tokenClass: TranslationPronounTokenClass
    public let antecedentLabel: String?
    public let evidenceScope: String
    public let expectedGuidance: TranslationExpectedPronounGuidance
    public let expectedEnglishStrategy: String
    public let mustAbstainWhenEvidenceMissing: Bool
    public let rationaleCode: String
}
