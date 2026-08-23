import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounPromptTests {
    @Test func promptTreatsSpokenTaConservativelyWithoutGuidance() {
        let prompt = HyMT2PromptBuilder.prompt(
            source: "他后来继续分享。",
            targetLanguage: "en",
            terms: [],
            strict: false
        )

        #expect(prompt.contains("Spoken Mandarin tā"))
        #expect(prompt.contains("never infer gender from a name, occupation, or stereotype"))
        #expect(prompt.contains("natural singular they"))
    }

    @Test func guidedPromptProtectsCurrentSourceAndDefinesPerIDRules() throws {
        let source = "她问他。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale), guidance(2, .unresolvedSpokenMandarin)]
        )
        let prompt = HyMT2PromptBuilder.prompt(
            source: source,
            targetLanguage: "en",
            terms: [],
            context: [
                TranslationContextEntry(sourceText: "她先前发言。", targetText: "She spoke earlier.")
            ],
            pronounPlan: plan,
            strict: false
        )

        #expect(prompt.contains(plan.protectedSource))
        assertProtectedOccurrences(plan, in: prompt)
        #expect(prompt.contains("P0001: verified female"))
        #expect(prompt.contains("P0002: unresolved spoken tā"))
        #expect(prompt.contains("Preserve every whole block and ID exactly once"))
        #expect(prompt.contains("between the English pronoun and the block's opening tag"))
        #expect(prompt.contains("protected block is protocol data"))
        #expect(prompt.contains("verified decisions below come from audited explicit evidence"))
        #expect(!prompt.contains("/>"))
        let background = try #require(prompt.range(of: "BACKGROUND FOR DISAMBIGUATION ONLY"))
        let pronounRules = try #require(prompt.range(of: "MANDATORY PRONOUN ALIGNMENT"))
        let currentSource = try #require(prompt.range(of: "<CURRENT_SOURCE>"))
        #expect(background.lowerBound < pronounRules.lowerBound)
        #expect(pronounRules.lowerBound < currentSource.lowerBound)
    }

    @Test func deityRuleRequiresConventionalPronounNotFreeNoun() throws {
        let source = "祂爱世人。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedDeity)]
        )
        let prompt = HyMT2PromptBuilder.prompt(
            source: source,
            targetLanguage: "en",
            terms: [],
            pronounPlan: plan,
            strict: false
        )

        #expect(prompt.contains("verified Christian deity pronoun"))
        #expect(prompt.contains("only conventional he/him/his/himself"))
    }
}

private func assertProtectedOccurrences(
    _ plan: HyMT2PronounPlan,
    in prompt: String
) {
    for occurrence in plan.occurrences {
        #expect(
            plan.protectedSource.contains(
                occurrence.modelVisibleGlyph + occurrence.protectedBlock
            )
        )
        #expect(prompt.components(separatedBy: occurrence.protectedBlock).count == 2)
        let token = HyMT2PronounResolutionToken.value(for: occurrence.resolution)
        #expect(prompt.components(separatedBy: token).count == 2)
    }
}
