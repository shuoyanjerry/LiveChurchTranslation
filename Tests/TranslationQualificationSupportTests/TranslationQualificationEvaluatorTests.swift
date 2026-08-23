import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationQualificationEvaluatorTests {
    @Test func evaluatesEveryPronounPolicyFromOccurrenceTraces() throws {
        let occurrences = try makeOccurrences()
        let guidance = zip(
            occurrences,
            [
                "verifiedMale", "verifiedFemale", "verifiedDeity",
                "unresolvedSpokenMandarin", nil, nil,
            ] as [String?]
        ).map {
            TranslationGuidanceObservation(
                occurrenceID: $0.0.id,
                resolution: $0.1
            )
        }
        let results = TranslationPronounEvaluator.evaluate(
            occurrences: occurrences,
            guidance: guidance,
            realizations: makeRealizations(occurrences),
            hypothesisAvailable: true
        )

        #expect(results.allSatisfy { $0.guidanceStatus == .pass })
        #expect(results.prefix(4).allSatisfy { $0.englishPolicyStatus == .pass })
        #expect(results.suffix(2).allSatisfy { $0.englishPolicyStatus == .humanReviewRequired })
    }

    private func makeRealizations(
        _ occurrences: [TranslationPronounOccurrence]
    ) -> [TranslationPronounRealizationObservation] {
        let policies = [
            ("verifiedMale", "masculine"),
            ("verifiedFemale", "feminine"),
            ("verifiedDeity", "masculine"),
            ("unresolvedSpokenMandarin", "singularThey"),
        ]
        return zip(occurrences.prefix(4), policies).map { occurrence, policy in
            TranslationPronounRealizationObservation(
                occurrenceID: occurrence.id,
                resolution: policy.0,
                realizationClass: policy.1
            )
        }
    }

    @Test func checksTermsNegationNumbersAndScriptureWithoutScoringReference() throws {
        let segment = try makePreservationSegment()
        let result = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "They do not read John 3:16 in 2026; grace remains.",
            terms: [
                TranslationQualificationTermExpectation(
                    source: "恩典",
                    preferredTarget: "grace",
                    required: true
                )
            ]
        )

        #expect(result.terms.map(\.status) == [.pass])
        #expect(result.checks.prefix(3).allSatisfy { $0.status == .pass })
        #expect(result.checks.suffix(2).allSatisfy { $0.status == .humanReviewRequired })
    }

    private func makeOccurrences() throws -> [TranslationPronounOccurrence] {
        let policies: [(String, String)] = [
            ("verifiedMale", "singularPronoun"), ("verifiedFemale", "singularPronoun"),
            ("deity", "singularPronoun"), ("unresolved", "singularPronoun"),
            ("pluralNeutral", "pluralPronoun"), ("lexicalNotPronoun", "lexicalOtherPeople"),
        ]
        let values: [[String: Any]] = policies.enumerated().map { index, policy in
            [
                "id": "occurrence-\(index)", "unicodeScalarOffset": index,
                "originalGlyph": "他", "observedGlyph": "他", "tokenClass": policy.1,
                "antecedentLabel": NSNull(), "evidenceScope": "synthetic",
                "expectedGuidance": policy.0, "expectedEnglishStrategy": "synthetic",
                "mustAbstainWhenEvidenceMissing": true, "rationaleCode": "synthetic",
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: values)
        return try JSONDecoder().decode([TranslationPronounOccurrence].self, from: data)
    }

    private func makePreservationSegment() throws -> TranslationQualificationSegment {
        let value: [String: Any] = [
            "id": "synthetic-segment", "sourceID": "synthetic-source", "sequence": 1,
            "unitKind": "content", "referenceProfileID": "synthetic-profile",
            "discourseContextIDs": [], "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": "他不看约翰福音3章16节和2026年的恩典。",
            "observedASRAmbiguousChinese": "他不看约翰福音3章16节和2026年的恩典。",
            "referenceEnglish": "Review-only synthetic reference.",
            "featureTags": ["negation", "number", "scripture", "theologyTerm"],
            "theologyTerms": ["恩典"], "pronounOccurrences": [], "referenceWarnings": [],
            "qualification": [
                "semanticScoringEligible": true, "exactStringScoringEligible": false,
                "asrCEREligible": false, "requiresHumanSemanticReview": true,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
    }
}
