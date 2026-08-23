public struct TranslationGuidanceObservation: Equatable, Sendable {
    public let occurrenceID: String
    public let resolution: String?

    public init(occurrenceID: String, resolution: String?) {
        self.occurrenceID = occurrenceID
        self.resolution = resolution
    }
}

public struct TranslationPronounRealizationObservation: Equatable, Sendable {
    public let occurrenceID: String
    public let resolution: String
    public let realizationClass: String

    public init(
        occurrenceID: String,
        resolution: String,
        realizationClass: String
    ) {
        self.occurrenceID = occurrenceID
        self.resolution = resolution
        self.realizationClass = realizationClass
    }
}

public enum TranslationPronounEvaluator {
    public static func evaluate(
        occurrences: [TranslationPronounOccurrence],
        guidance: [TranslationGuidanceObservation],
        realizations: [TranslationPronounRealizationObservation],
        hypothesisAvailable: Bool
    ) -> [TranslationQualificationPronounResult] {
        let guidanceByID = uniqueGuidance(guidance)
        let tracesByID = Dictionary(grouping: realizations, by: \.occurrenceID)
        return occurrences.map { occurrence in
            result(
                occurrence,
                actualGuidance: guidanceByID[occurrence.id] ?? nil,
                traces: tracesByID[occurrence.id, default: []],
                hypothesisAvailable: hypothesisAvailable
            )
        }
    }

    private static func uniqueGuidance(
        _ values: [TranslationGuidanceObservation]
    ) -> [String: String?] {
        Dictionary(grouping: values, by: \.occurrenceID).mapValues { matches in
            matches.count == 1 ? matches[0].resolution : nil
        }
    }

    private static func result(
        _ occurrence: TranslationPronounOccurrence,
        actualGuidance: String?,
        traces: [TranslationPronounRealizationObservation],
        hypothesisAvailable: Bool
    ) -> TranslationQualificationPronounResult {
        let expected = expectedGuidance(occurrence.expectedGuidance)
        let guidanceValue = actualGuidance ?? "none"
        let guidanceStatus: TranslationQualificationCheckStatus =
            guidanceValue == expected ? .pass : .fail
        let english = englishAudit(
            occurrence,
            traces: traces,
            hypothesisAvailable: hypothesisAvailable
        )
        return TranslationQualificationPronounResult(
            occurrenceID: occurrence.id,
            expectedGuidance: occurrence.expectedGuidance,
            actualGuidance: guidanceValue,
            guidanceStatus: guidanceStatus,
            englishToken: nil,
            englishClass: english.classification,
            englishPolicyStatus: english.status
        )
    }

    private static func englishAudit(
        _ occurrence: TranslationPronounOccurrence,
        traces: [TranslationPronounRealizationObservation],
        hypothesisAvailable: Bool
    ) -> (classification: String, status: TranslationQualificationCheckStatus) {
        guard hypothesisAvailable else { return ("noHypothesis", .fail) }
        guard occurrence.tokenClass == .singularPronoun else {
            return (nonSingularClass(occurrence.tokenClass), .humanReviewRequired)
        }
        guard traces.count == 1, let trace = traces.first else {
            return (traces.isEmpty ? "missingTrace" : "duplicateTrace", .fail)
        }
        let expectedResolution = expectedGuidance(occurrence.expectedGuidance)
        let expectedClass = expectedRealization(occurrence.expectedGuidance)
        let passes =
            trace.resolution == expectedResolution
            && trace.realizationClass == expectedClass
        return (trace.realizationClass, passes ? .pass : .fail)
    }

    private static func expectedGuidance(_ expected: TranslationExpectedPronounGuidance) -> String {
        switch expected {
        case .verifiedMale: "verifiedMale"
        case .verifiedFemale: "verifiedFemale"
        case .deity: "verifiedDeity"
        case .unresolved: "unresolvedSpokenMandarin"
        case .pluralNeutral, .lexicalNotPronoun: "none"
        }
    }

    private static func expectedRealization(
        _ expected: TranslationExpectedPronounGuidance
    ) -> String {
        switch expected {
        case .verifiedMale, .deity: "masculine"
        case .verifiedFemale: "feminine"
        case .unresolved: "singularThey"
        case .pluralNeutral: "pluralNeutral"
        case .lexicalNotPronoun: "lexicalNotPronoun"
        }
    }

    private static func nonSingularClass(_ value: TranslationPronounTokenClass) -> String {
        value == .pluralPronoun ? "pluralNeutral" : "lexicalNotPronoun"
    }
}
