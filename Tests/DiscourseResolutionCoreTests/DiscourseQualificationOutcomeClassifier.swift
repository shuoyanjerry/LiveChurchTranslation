import TranslationQualificationSupport

enum DiscourseQualificationOutcomeClassifier {
    private static let automaticClasses: Set<String> = [
        "verifiedMale", "verifiedFemale", "verifiedDeity",
    ]
    private static let mappingFailureClasses: Set<String> = [
        "duplicateGuidance", "invalidGuidanceRange",
    ]

    static func classify(
        expected: TranslationExpectedPronounGuidance,
        actual: String
    ) -> DiscourseQualificationOutcomeClass {
        if mappingFailureClasses.contains(actual) { return .mappingFailure }
        if let expectedAutomatic = automaticClass(expected) {
            if actual == expectedAutomatic { return .correctAutomaticResolution }
            return automaticClasses.contains(actual)
                ? .wrongAutomaticResolution : .missedResolvable
        }
        if automaticClasses.contains(actual) { return .wrongAutomaticResolution }
        return expected == .unresolved ? .safeAbstention : .safeProtection
    }

    static func isPolicyMatch(
        _ status: TranslationQualificationCheckStatus
    ) -> DiscourseQualificationPolicyStatus {
        status == .pass ? .pass : .fail
    }

    private static func automaticClass(
        _ expected: TranslationExpectedPronounGuidance
    ) -> String? {
        switch expected {
        case .verifiedMale: "verifiedMale"
        case .verifiedFemale: "verifiedFemale"
        case .deity: "verifiedDeity"
        case .unresolved, .pluralNeutral, .lexicalNotPronoun: nil
        }
    }
}
