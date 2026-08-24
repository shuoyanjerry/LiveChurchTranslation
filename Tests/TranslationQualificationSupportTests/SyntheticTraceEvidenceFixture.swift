import Foundation
import TranslationQualificationSupport

enum SyntheticTraceEvidenceFixture {
    static func segment(
        tokenClasses: [TranslationPronounTokenClass]
    ) throws -> TranslationQualificationSegment {
        let pronounText = String(repeating: "他", count: tokenClasses.count)
        let source = pronounText.isEmpty ? "合成标题" : pronounText + "仍在这里。"
        let occurrences = tokenClasses.enumerated().map { index, tokenClass in
            [
                "id": "synthetic-trace-\(index)",
                "unicodeScalarOffset": index,
                "originalGlyph": "他",
                "observedGlyph": "他",
                "tokenClass": tokenClass.rawValue,
                "antecedentLabel": NSNull(),
                "evidenceScope": "synthetic",
                "expectedGuidance": expectedGuidance(tokenClass),
                "expectedEnglishStrategy": "synthetic",
                "mustAbstainWhenEvidenceMissing": true,
                "rationaleCode": "synthetic",
            ] as [String: Any]
        }
        let data = try JSONSerialization.data(
            withJSONObject: SyntheticTraceSegmentValue.make(
                source: source,
                occurrences: occurrences
            )
        )
        return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
    }

    static func attempt(
        segment: TranslationQualificationSegment,
        status: TranslationQualificationAttemptStatus = .success,
        traceStatus: TranslationQualificationCheckStatus
    ) -> TranslationQualificationAttempt {
        let hypothesis = status == .success ? "Synthetic translation." : nil
        let preservation = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: hypothesis,
            terms: []
        )
        return TranslationQualificationAttempt(
            segment: segment,
            status: status,
            hypothesisEnglish: hypothesis,
            translationSourceText: segment.observedASRAmbiguousChinese,
            contextSegmentIDs: [],
            strictRetryUsed: false,
            safetyFallbackUsed: false,
            completionAttemptCount: status == .success ? 1 : 0,
            completionOutcomes: status == .success ? ["initial.accepted"] : [],
            latencySeconds: 0.1,
            failureCode: status == .failure ? "synthetic.failure" : nil,
            glossaryTerms: preservation.terms,
            preservationChecks: preservation.checks + [
                TranslationQualificationCheck(
                    kind: "pronounTraceIntegrity",
                    status: traceStatus
                )
            ],
            pronounResults: TranslationPronounEvaluator.evaluate(
                occurrences: segment.pronounOccurrences,
                guidance: guidance(segment.pronounOccurrences),
                realizations: realizations(segment.pronounOccurrences, hypothesis: hypothesis),
                hypothesisAvailable: hypothesis != nil
            )
        )
    }

    private static func expectedGuidance(_ tokenClass: TranslationPronounTokenClass) -> String {
        switch tokenClass {
        case .singularPronoun: "unresolved"
        case .pluralPronoun: "pluralNeutral"
        case .lexicalOtherPeople: "lexicalNotPronoun"
        }
    }

    private static func guidance(
        _ occurrences: [TranslationPronounOccurrence]
    ) -> [TranslationGuidanceObservation] {
        occurrences.map {
            TranslationGuidanceObservation(
                occurrenceID: $0.id,
                resolution: $0.tokenClass == .singularPronoun
                    ? "unresolvedSpokenMandarin" : nil
            )
        }
    }

    private static func realizations(
        _ occurrences: [TranslationPronounOccurrence],
        hypothesis: String?
    ) -> [TranslationPronounRealizationObservation] {
        guard hypothesis != nil else { return [] }
        return occurrences.compactMap {
            guard $0.tokenClass == .singularPronoun else { return nil }
            return TranslationPronounRealizationObservation(
                occurrenceID: $0.id,
                resolution: "unresolvedSpokenMandarin",
                realizationClass: "singularThey"
            )
        }
    }
}

private enum SyntheticTraceSegmentValue {
    static func make(
        source: String,
        occurrences: [[String: Any]]
    ) -> [String: Any] {
        [
            "id": "synthetic-trace-segment",
            "sourceID": "synthetic-trace-source",
            "sequence": 1,
            "unitKind": "content",
            "referenceProfileID": "synthetic-profile",
            "discourseContextIDs": [],
            "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": source,
            "observedASRAmbiguousChinese": source,
            "referenceEnglish": "Synthetic review-only reference.",
            "featureTags": [],
            "theologyTerms": [],
            "pronounOccurrences": occurrences,
            "referenceWarnings": [],
            "qualification": [
                "semanticScoringEligible": false,
                "exactStringScoringEligible": false,
                "asrCEREligible": false,
                "requiresHumanSemanticReview": false,
            ],
        ]
    }
}
