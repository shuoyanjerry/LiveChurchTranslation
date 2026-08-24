import Foundation
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

        #expect(prompt.contains("口语 tā 即使写成他或她也可能没有性别证据"))
        #expect(prompt.contains("无明确证据时使用自然的单数 they"))
        #expect(prompt.contains("不要使用 he 或 she"))
        #expect(prompt.contains("不要根据姓名、职业或刻板印象猜测"))
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
        #expect(prompt.contains("N=性别未知的单数人物"))
        #expect(prompt.contains("忽略标记前的他或她字形"))
        #expect(prompt.contains("禁止使用 he 或 she"))
        #expect(prompt.contains("F=已确认女性，只选一个符合句法的 she 形式"))
        #expect(prompt.contains("把标记原样放在该英文代词后"))
        #expect(prompt.contains("每个标记只出现一次"))
        #expect(prompt.contains("每处只能输出一个符合句法的代词"))
        #expect(prompt.contains("禁止列出备选词或使用斜线"))
        #expect(!prompt.contains("QLR_"))
        #expect(!prompt.contains("protected block is protocol data"))
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

        #expect(prompt.contains("D=基督教神性指代，只选一个符合句法的 he 形式"))
        #expect(!prompt.contains("himself"))
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
        #expect(occurrence.modelVisibleGlyph == occurrence.sourceGlyph)
        #expect(
            occurrence.protectedBlock.range(
                of: #"^<Q[A-F0-9]{12}P[0-9]{4}[NFMD]>$"#,
                options: .regularExpression
            ) != nil
        )
    }
}
