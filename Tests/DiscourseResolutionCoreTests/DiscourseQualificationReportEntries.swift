enum DiscourseQualificationOutcomeClass: String, Codable, Sendable {
    case correctAutomaticResolution
    case missedResolvable
    case safeAbstention
    case safeProtection
    case wrongAutomaticResolution
    case mappingFailure
}

enum DiscourseQualificationPolicyStatus: String, Codable, Sendable {
    case pass
    case fail
}

struct DiscourseQualificationOccurrenceReport: Codable, Sendable {
    let occurrenceID: String
    let expectedGuidanceClass: String
    let actualGuidanceClass: String
    let outcomeClass: DiscourseQualificationOutcomeClass
    let policyStatusClass: DiscourseQualificationPolicyStatus
}

struct DiscourseQualificationSegmentReport: Codable, Sendable {
    let segmentID: String
    let sourceID: String
    let sequence: Int
    let inputSHA256: String
    let resolvedSHA256: String
    let contextSegmentIDs: [String]
    let contextTextSHA256s: [String]
    let correctionCount: Int
    let correctionClasses: [String]
    let guidanceCount: Int
    let unmappedGuidanceCount: Int
    let duplicateGuidanceLocationCount: Int
    let ambiguityClasses: [String]
    let constraintClasses: [String]
    let occurrences: [DiscourseQualificationOccurrenceReport]
}

struct DiscourseQualificationResolverMetadata: Codable, Sendable {
    let identifier: String
    let contextWindowCount: Int
    let persistenceClass: String
    let orderingClass: String
}
