enum TranslationPronounResultValidator {
    static func validate(
        _ results: [TranslationQualificationPronounResult],
        occurrences: [TranslationPronounOccurrence],
        hypothesisAvailable: Bool,
        traceIntegrity: TranslationQualificationCheckStatus
    ) throws {
        for (result, occurrence) in zip(results, occurrences) {
            let expected = expectedGuidance(occurrence.expectedGuidance)
            let status: TranslationQualificationCheckStatus =
                result.actualGuidance == expected ? .pass : .fail
            try require(result.guidanceStatus == status, "pronoun guidance status is inconsistent")
            try require(result.englishToken == nil, "raw pronoun token must not enter report")
            let english = try expectedEnglish(
                result,
                occurrence: occurrence,
                hypothesisAvailable: hypothesisAvailable,
                traceIntegrity: traceIntegrity
            )
            try require(
                result.englishClass == english.classification
                    && result.englishPolicyStatus == english.status,
                "pronoun English policy is inconsistent"
            )
        }
    }

    private static func expectedEnglish(
        _ result: TranslationQualificationPronounResult,
        occurrence: TranslationPronounOccurrence,
        hypothesisAvailable: Bool,
        traceIntegrity: TranslationQualificationCheckStatus
    ) throws -> (classification: String, status: TranslationQualificationCheckStatus) {
        guard hypothesisAvailable else { return ("noHypothesis", .fail) }
        guard occurrence.tokenClass == .singularPronoun else {
            let value =
                occurrence.tokenClass == .pluralPronoun
                ? "pluralNeutral" : "lexicalNotPronoun"
            return (value, .humanReviewRequired)
        }
        guard traceIntegrity == .pass else { return ("missingTrace", .fail) }
        guard let classification = realization(for: result.actualGuidance) else {
            return ("missingTrace", .fail)
        }
        let policy: TranslationQualificationCheckStatus =
            result.actualGuidance == expectedGuidance(occurrence.expectedGuidance)
            ? .pass : .fail
        return (classification, policy)
    }

    private static func realization(for guidance: String) -> String? {
        switch guidance {
        case "verifiedMale", "verifiedDeity": "masculine"
        case "verifiedFemale": "feminine"
        case "unresolvedSpokenMandarin": "singularThey"
        case "none": nil
        default: nil
        }
    }

    private static func expectedGuidance(
        _ value: TranslationExpectedPronounGuidance
    ) -> String {
        switch value {
        case .verifiedMale: "verifiedMale"
        case .verifiedFemale: "verifiedFemale"
        case .deity: "verifiedDeity"
        case .unresolved: "unresolvedSpokenMandarin"
        case .pluralNeutral, .lexicalNotPronoun: "none"
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }
}
