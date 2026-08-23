import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounDiagnosticAggregationTests {
    @Test func reportsEveryPolicyMismatchWithoutRawRealizations() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .verifiedMale)]
        )
        let output = "\(anchored(plan, 0, "he")) asked \(anchored(plan, 1, "she"))."
        let issues = validationIssues(output: output, source: source, plan: plan)
        let descriptions = issues.map(\.description)

        #expect(
            descriptions == [
                "pronoun marker P0001 expected verifiedFemale, observed male",
                "pronoun marker P0002 expected verifiedMale, observed female",
            ])
        #expect(!descriptions.joined().contains("asked"))
    }
}
