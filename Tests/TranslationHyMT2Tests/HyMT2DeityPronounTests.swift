import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2DeityPronounTests {
    @Test func deityAndUnresolvedAreValidatedIndependently() throws {
        let source = "祂呼召他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedDeity), guidance(3, .unresolvedSpokenMandarin)]
        )
        let output = "\(anchored(plan, 0, "He")) called \(anchored(plan, 1, "them"))."

        _ = try validate(output, source: source, plan: plan)
        let wrong = "\(anchored(plan, 0, "They")) called \(anchored(plan, 1, "him"))."
        #expect(!validationIssues(output: wrong, source: source, plan: plan).isEmpty)
    }

    @Test func femaleAndDeityAreValidatedIndependently() throws {
        let source = "她感谢祂。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(3, .verifiedDeity)]
        )
        let output = "\(anchored(plan, 0, "She")) thanked \(anchored(plan, 1, "Him"))."

        _ = try validate(output, source: source, plan: plan)
        let swapped = "\(anchored(plan, 0, "He")) thanked \(anchored(plan, 1, "her"))."
        #expect(!validationIssues(output: swapped, source: source, plan: plan).isEmpty)
    }

    @Test func deityPronounCannotBecomeFreeNounInsideMarker() throws {
        let source = "祂爱世人。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedDeity)]
        )
        let output = "\(anchored(plan, 0, "God")) loves the world."

        #expect(
            validationIssues(output: output, source: source, plan: plan).contains(
                .wrongPronounRealization(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedDeity,
                    .singleOtherToken
                )
            ))
    }

    private func validate(
        _ output: String,
        source: String,
        plan: HyMT2PronounPlan
    ) throws -> String {
        try HyMT2OutputValidator.validate(
            output,
            source: source,
            requiredTerms: [],
            pronounPlan: plan
        )
    }
}
