import Testing

@Suite("Hy-MT2 test-only negation shadow assessment")
struct HyMT2NegationShadowAssessmentTests {
    @Test("records pass metadata without source or target text")
    func recordsPass() throws {
        let plan = try HyMT2NegationShadowFixtures.singleNot.plan(encoding: .englishNot)
        let marker = try #require(plan.occurrences.first).protectedBlock
        let assessment = HyMT2NegationShadowAssessment.evaluate(
            "The church does not\(marker) hide truth.",
            plan: plan
        )

        #expect(assessment.encoding == .englishNot)
        #expect(assessment.occurrenceCount == 1)
        #expect(assessment.outcome == .passed)
        #expect(assessment.outcome.code == "neg.shadow.pass")
    }

    @Test("records only the stable failure category")
    func recordsFailureCategory() throws {
        let plan = try HyMT2NegationShadowFixtures.two.plan(encoding: .originalCue)
        let assessment = HyMT2NegationShadowAssessment.evaluate(
            "The translation omits both negative propositions.",
            plan: plan
        )

        #expect(assessment.encoding == .originalCue)
        #expect(assessment.occurrenceCount == 2)
        #expect(assessment.outcome == .failed(.missingBlock))
        #expect(assessment.outcome.code == "neg.shadow.block.missing")
    }

    @Test("keeps every log-safe outcome code bounded")
    func keepsCodesLogSafe() {
        let outcomes =
            [HyMT2NegationShadowOutcome.passed]
            + HyMT2NegationShadowFailureCategory.allCases.map {
                HyMT2NegationShadowOutcome.failed($0)
            }
        for code in outcomes.map(\.code) {
            #expect(code.count <= 64)
            #expect(code.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "." })
        }
    }
}
