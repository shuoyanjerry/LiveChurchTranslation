extension TranslationManifestShapeValidator {
    static let rootKeys = Set([
        "schemaVersion", "schemaPath", "corpusID", "generatedAt", "visibility", "provenance",
        "policy", "referenceProfiles", "sources", "segments", "candidateSources", "summary",
    ])
    static let provenanceKeys = Set([
        "parentCorpusManifestPath", "parentCorpusManifestSHA256", "searchProvider",
        "sourcesReviewedInParentResearch", "latestExtensionStatus", "builderSHA256",
        "configSHA256", "candidateConfigSHA256", "supportSHA256",
    ])
    static let policyKeys = Set([
        "taDegradation", "genderRule", "referenceRule", "copyrightRule",
    ])
    static let profileKeys = Set([
        "id", "spokenTextClass", "spokenAudioVerification", "translationClass",
        "exactStringMetricEligible", "allowedQualification", "forbiddenQualification",
        "knownLimitations",
    ])
    static let sourceKeys = Set([
        "id", "provider", "titleChinese", "titleEnglish", "speaker", "sourcePageURL",
        "referenceURL", "audioURL", "audioLocalPath", "audioSHA256", "audioAlignment",
        "referenceLocalPath", "referenceSHA256", "extractedTextLocalPath",
        "extractedTextSHA256", "pageCount", "pairCount", "referenceProfileID", "rights",
    ])
    static let rightsKeys = Set([
        "classification", "evidenceURL", "localPrivateQAAllowed", "trainingAllowed",
        "redistributionAllowed", "mustNotCommit",
    ])
    static let segmentKeys = Set([
        "id", "sourceID", "sequence", "unitKind", "referenceProfileID", "discourseContextIDs",
        "locator", "originalChinese", "observedASRAmbiguousChinese", "referenceEnglish",
        "featureTags", "theologyTerms", "pronounOccurrences", "referenceWarnings", "qualification",
    ])
    static let locatorKeys = Set(["chinesePages", "englishPages"])
    static let qualificationKeys = Set([
        "semanticScoringEligible", "exactStringScoringEligible", "asrCEREligible",
        "requiresHumanSemanticReview",
    ])
    static let occurrenceKeys = Set([
        "id", "unicodeScalarOffset", "originalGlyph", "observedGlyph", "tokenClass",
        "antecedentLabel", "evidenceScope", "expectedGuidance", "expectedEnglishStrategy",
        "mustAbstainWhenEvidenceMissing", "rationaleCode",
    ])
    static let summaryKeys = Set([
        "sourceCount", "segmentPairCount", "contentPairCount", "headingOrTitlePairCount",
        "sourcePairCounts", "featureTagCounts", "taGlyphOccurrenceCount", "pronounGuidanceCounts",
        "grnCandidateCount", "hesedExcludedCount",
    ])
}
