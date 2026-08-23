import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounPunctuationDiagnosticTests {
    @Test func parserReportsPunctuatedClassWithoutAcceptingIt() throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output = "\(anchored(plan, 0, "“she,”")) continued."
        let issues = validationIssues(output: output, source: source, plan: plan)

        #expect(
            issues.first?.description
                == "pronoun marker P0001 expected verifiedFemale, observed punctuatedFemale")
    }
}
