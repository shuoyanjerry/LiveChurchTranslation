import Foundation
import Testing
@testable import TranslationQualificationSupport

@Suite struct TranslationPreservationPolicyTests {
    @Test func preferredTermMissRequiresReviewWhileRequiredTermMissFails() throws {
        let segment = try makeSegment(source: "这是恩典。")
        let required = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "This is kindness.",
            terms: [
                TranslationQualificationTermExpectation(
                    source: "恩典",
                    preferredTarget: "grace",
                    required: true
                )
            ]
        )
        let preferred = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "This is kindness.",
            terms: [
                TranslationQualificationTermExpectation(
                    source: "恩典",
                    preferredTarget: "grace",
                    required: false
                )
            ]
        )

        #expect(required.terms.first?.status == .fail)
        #expect(preferred.terms.first?.status == .humanReviewRequired)
    }

    @Test func surfaceNegationMismatchRequiresReviewWithSafeMachineFacts() throws {
        let segment = try makeSegment(source: "救恩不是行为，也不能自取。")
        let mismatch = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "Salvation comes from works and can be earned.",
            terms: []
        )
        let passed = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "Salvation is not from works and cannot be earned.",
            terms: []
        )
        let mismatchCheck = try #require(
            mismatch.checks.first { $0.kind == "negation" }
        )
        let passedCheck = try #require(
            passed.checks.first { $0.kind == "negation" }
        )

        #expect(mismatchCheck.status == .humanReviewRequired)
        #expect(
            mismatchCheck.expected == ["machine.source_surface_negation_cue_count=2"]
        )
        #expect(
            mismatchCheck.observed == ["machine.target_overt_negation_cue_count=0"]
        )
        #expect(passedCheck.status == .pass)
        #expect(passedCheck.expected == mismatchCheck.expected)
        #expect(passedCheck.observed == ["machine.target_overt_negation_cue_count=2"])
        #expect(
            (mismatchCheck.expected + mismatchCheck.observed).allSatisfy {
                $0.unicodeScalars.allSatisfy(\.isASCII)
            }
        )
    }

    @Test func noSourceNegationIsNotApplicableAndMissingTargetFailsClosed() throws {
        let noSourceCue = TranslationPreservationEvaluator.evaluate(
            segment: try makeSegment(source: "恩典够用。"),
            hypothesis: "Grace is not scarce.",
            terms: []
        )
        let unavailable = TranslationPreservationEvaluator.evaluate(
            segment: try makeSegment(source: "神不离弃我们。"),
            hypothesis: nil,
            terms: []
        )
        let noSourceCheck = try #require(
            noSourceCue.checks.first { $0.kind == "negation" }
        )
        let unavailableCheck = try #require(
            unavailable.checks.first { $0.kind == "negation" }
        )

        #expect(noSourceCheck.status == .notApplicable)
        #expect(noSourceCheck.expected == ["machine.source_surface_negation_cue_count=0"])
        #expect(noSourceCheck.observed == ["machine.target_overt_negation_cue_count=1"])
        #expect(unavailableCheck.status == .fail)
        #expect(unavailableCheck.expected == ["machine.source_surface_negation_cue_count=1"])
        #expect(unavailableCheck.observed == ["machine.target_availability=missing"])
    }

    private func makeSegment(source: String) throws -> TranslationQualificationSegment {
        let value: [String: Any] = [
            "id": "synthetic-segment", "sourceID": "synthetic-source", "sequence": 1,
            "unitKind": "content", "referenceProfileID": "synthetic-profile",
            "discourseContextIDs": [], "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": source, "observedASRAmbiguousChinese": source,
            "referenceEnglish": "Review-only synthetic reference.",
            "featureTags": ["negation", "theologyTerm"], "theologyTerms": ["恩典"],
            "pronounOccurrences": [], "referenceWarnings": [],
            "qualification": [
                "semanticScoringEligible": true, "exactStringScoringEligible": false,
                "asrCEREligible": false, "requiresHumanSemanticReview": true,
            ],
        ]
        return try JSONDecoder().decode(
            TranslationQualificationSegment.self,
            from: JSONSerialization.data(withJSONObject: value)
        )
    }
}
