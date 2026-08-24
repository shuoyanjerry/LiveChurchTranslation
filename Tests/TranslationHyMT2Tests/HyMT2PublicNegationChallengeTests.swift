import Testing
@testable import TranslationHyMT2

@Suite("Hy-MT2 deterministic public negation challenge")
struct HyMT2PublicNegationChallengeTests {
    @Test(arguments: PublicNegationChallengeFixtures.repairedCountLosses)
    func catchesIndependentNegationLoss(fixture: PublicNegationChallengeFixture) {
        let issues = validationIssues(fixture)

        #expect(fixture.humanOracle == .reject)
        #expect(issues.contains(.missingNegation))
    }

    @Test(arguments: PublicNegationChallengeFixtures.formerFalseRejects)
    func acceptsNonfunctionalAndFaithfulLexicalRealizations(
        fixture: PublicNegationChallengeFixture
    ) {
        let issues = validationIssues(fixture)

        #expect(fixture.humanOracle == .accept)
        #expect(!issues.contains(.missingNegation))
    }

    @Test(arguments: PublicNegationChallengeFixtures.scopeLimitations)
    func doesNotPretendSurfaceCountsCanJudgeScope(
        fixture: PublicNegationChallengeFixture
    ) {
        let issues = validationIssues(fixture)

        #expect(fixture.humanOracle == .reject)
        #expect(!issues.contains(.missingNegation))
    }

    @Test("fixtures explicitly cover all three policies and required constructions")
    func challengeCoverageIsExplicit() {
        let policies = PublicNegationChallengeFixtures.all.map(\.policy)
        let identifiers = Set(PublicNegationChallengeFixtures.all.map(\.id))

        #expect(policies.contains(.mustPreserveCount(1)))
        #expect(policies.contains(.mustPreserveCount(2)))
        #expect(policies.contains(.mustPreserveCount(3)))
        #expect(policies.contains(.nonFunctional))
        #expect(policies.contains(.humanReview))
        #expect(requiredConstructionIDs.isSubset(of: identifiers))
    }

    private func validationIssues(
        _ fixture: PublicNegationChallengeFixture
    ) -> [OutputValidationIssue] {
        HyMT2FidelityValidator.issues(
            target: fixture.target,
            source: fixture.source,
            requiredTerms: []
        )
    }

    private var requiredConstructionIDs: Set<String> {
        [
            "single-bare-negation-scope-shift",
            "two-independent-negations-one-lost",
            "three-independent-negations-two-lost",
            "quantifier-scope-not-all-to-none",
            "a-not-a-question",
            "bu-de-bu-necessity",
            "bu-neng-bu-necessity",
            "bu-dan-additive",
            "bu-jin-additive",
            "bu-lun-concessive",
            "bu-guan-concessive",
            "bu-tong-lexical",
            "bu-duan-lexical",
            "bu-an-lexical",
            "lexical-negative-powerless",
            "positive-imperative-paraphrase",
        ]
    }
}
