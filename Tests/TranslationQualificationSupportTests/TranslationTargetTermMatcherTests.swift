import Testing
import TranslationQualificationSupport

@Suite struct TranslationTargetTermMatcherTests {
    @Test func rejectsSubstringFalsePositives() throws {
        let segment = try fixtureSegment()
        for hypothesis in ["Since then.", "Unfaithfulness remains."] {
            let result = evaluate(
                segment,
                hypothesis: hypothesis,
                preferred: hypothesis.hasPrefix("Since") ? "sin" : "faith"
            )
            #expect(result.terms.first?.status == .fail)
        }
    }

    @Test func acceptsWholeWordsAndContiguousPhrases() throws {
        let segment = try fixtureSegment()
        let cases = [
            ("Sin was forgiven.", "sin"),
            ("THE HOLY SPIRIT came.", "the Holy Spirit"),
            ("They shared the Lord’s Supper.", "the Lord's Supper"),
            ("They were born-again.", "born again"),
            ("Christ’s mercy remains.", "Christ"),
        ]
        for (hypothesis, preferred) in cases {
            let result = evaluate(segment, hypothesis: hypothesis, preferred: preferred)
            #expect(result.terms.first?.status == .pass)
        }
    }

    @Test func acceptsOnlyExplicitAlternatives() throws {
        let segment = try fixtureSegment()
        let expectation = TranslationQualificationTermExpectation(
            source: "这里",
            preferredTarget: "regeneration",
            acceptedTargets: ["born again"],
            required: true
        )
        let result = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "They were born again.",
            terms: [expectation]
        )
        #expect(result.terms.first?.status == .pass)
    }

    private func fixtureSegment() throws -> TranslationQualificationSegment {
        try SyntheticTranslationWorkspace().load().manifest.segments[1]
    }

    private func evaluate(
        _ segment: TranslationQualificationSegment,
        hypothesis: String,
        preferred: String
    ) -> TranslationQualificationPreservation {
        TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: hypothesis,
            terms: [
                TranslationQualificationTermExpectation(
                    source: "这里",
                    preferredTarget: preferred,
                    required: true
                )
            ]
        )
    }
}
