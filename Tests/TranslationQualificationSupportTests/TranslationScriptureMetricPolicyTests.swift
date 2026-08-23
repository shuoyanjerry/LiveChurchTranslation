import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationScriptureMetricPolicyTests {
    @Test func taggedScriptureWithoutExplicitReferenceRequiresHumanReview() throws {
        let result = TranslationPreservationEvaluator.evaluate(
            segment: try taggedScriptureSegment(source: "这段话引用了经文。"),
            hypothesis: "This passage quotes Scripture.",
            terms: []
        )

        let check = try #require(
            result.checks.first { $0.kind == "scriptureReference" }
        )
        #expect(check.status == .humanReviewRequired)
        #expect(check.expected.isEmpty)
        #expect(check.observed.isEmpty)
    }

    @Test func explicitChapterAndVerseRemainAHardMachineCheck() throws {
        let segment = try taggedScriptureSegment(source: "约翰福音3章16节。")
        let failed = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "John records this verse.",
            terms: []
        )
        let passed = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "John 3:16 records this verse.",
            terms: []
        )

        #expect(scriptureStatus(failed) == .fail)
        #expect(scriptureStatus(passed) == .pass)
    }

    private func scriptureStatus(
        _ result: TranslationQualificationPreservation
    ) -> TranslationQualificationCheckStatus? {
        result.checks.first { $0.kind == "scriptureReference" }?.status
    }

    private func taggedScriptureSegment(
        source: String
    ) throws -> TranslationQualificationSegment {
        let value: [String: Any] = [
            "id": "scripture-policy", "sourceID": "synthetic", "sequence": 1,
            "unitKind": "content", "referenceProfileID": "synthetic-profile",
            "discourseContextIDs": [], "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": source, "observedASRAmbiguousChinese": source,
            "referenceEnglish": "Review-only reference.", "featureTags": ["scripture"],
            "theologyTerms": [], "pronounOccurrences": [], "referenceWarnings": [],
            "qualification": [
                "semanticScoringEligible": true, "exactStringScoringEligible": false,
                "asrCEREligible": false, "requiresHumanSemanticReview": true,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
    }
}
