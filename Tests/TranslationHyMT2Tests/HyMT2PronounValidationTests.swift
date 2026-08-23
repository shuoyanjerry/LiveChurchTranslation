import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounValidationTests {
    @Test func acceptsFemaleAndMaleRealizationsByOccurrence() throws {
        let source = "她先说，然后他继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(6, .verifiedMale)]
        )
        let output = "\(anchored(plan, 0, "She")) spoke, then \(anchored(plan, 1, "he")) continued."

        let clean = try validate(output, source: source, plan: plan)

        #expect(clean == "She spoke, then he continued.")
        #expect(!clean.contains("QLR_"))
    }

    @Test func rejectsSwappedFemaleAndMaleRealizations() throws {
        let source = "她先说，然后他继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(6, .verifiedMale)]
        )
        let output = "\(anchored(plan, 0, "He")) spoke, then \(anchored(plan, 1, "she")) continued."

        #expect(
            issues(output, source: source, plan: plan).contains(
                .wrongPronounRealization(
                    "P0001",
                    TranslationSourceRange(location: 0, length: 1),
                    .verifiedFemale,
                    .male
                )
            ))
    }

    @Test func femaleAndUnresolvedRequireSheThenThey() throws {
        let source = "她先说，然后他继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(6, .unresolvedSpokenMandarin)]
        )
        let accepted = "\(anchored(plan, 0, "She")) spoke; \(anchored(plan, 1, "they")) continued."
        let allFemale = "\(anchored(plan, 0, "She")) spoke; \(anchored(plan, 1, "she")) continued."
        let maleThenThey = "\(anchored(plan, 0, "He")) spoke; \(anchored(plan, 1, "they")) continued."

        _ = try validate(accepted, source: source, plan: plan)
        #expect(!issues(allFemale, source: source, plan: plan).isEmpty)
        #expect(!issues(maleThenThey, source: source, plan: plan).isEmpty)
    }

    @Test func noGuidancePathDoesNotInferFromASRGlyph() throws {
        let output = try HyMT2OutputValidator.validate(
            "He continued sharing.",
            source: "他继续分享。",
            requiredTerms: []
        )

        #expect(output == "He continued sharing.")
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

    private func issues(
        _ output: String,
        source: String,
        plan: HyMT2PronounPlan
    ) -> [OutputValidationIssue] {
        validationIssues(output: output, source: source, plan: plan)
    }
}
