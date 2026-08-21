import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PromptBuilderTests {
    @Test func includesOnlyTermsMatchedByCurrentSource() {
        let source = "我们因信称义，全是恩典。"
        let glossary = [
            TranslationTerm(source: "因信称义", target: "justification by faith"),
            TranslationTerm(source: "恩典", target: "grace"),
            TranslationTerm(source: "洗礼", target: "baptism"),
        ]

        let matched = TranslationTermMatcher.matched(
            in: source,
            from: glossary,
            limit: 64
        )
        let prompt = HyMT2PromptBuilder.prompt(
            source: source,
            targetLanguage: "en",
            terms: matched,
            strict: false
        )

        #expect(prompt.contains("因信称义 translates to justification by faith"))
        #expect(prompt.contains("恩典 translates to grace"))
        #expect(!prompt.contains("洗礼"))
        #expect(prompt.hasSuffix(source))
    }

    @Test func deduplicatesTermsAndExcludesContainedMatches() {
        let terms = [
            TranslationTerm(source: "称义", target: "justification"),
            TranslationTerm(source: "因信称义", target: "justification by faith"),
            TranslationTerm(source: "称义", target: "being justified"),
        ]

        let matched = TranslationTermMatcher.matched(
            in: "我们因信称义",
            from: terms,
            limit: 2
        )

        #expect(matched.map(\.source) == ["因信称义"])
    }

    @Test func retainsShorterTermWhenItAlsoOccursOutsideLongerPhrase() {
        let terms = [
            TranslationTerm(source: "称义", target: "justification"),
            TranslationTerm(source: "因信称义", target: "justification by faith"),
        ]

        let matched = TranslationTermMatcher.matched(
            in: "称义，尤其是因信称义",
            from: terms,
            limit: 2
        )

        #expect(matched.map(\.source) == ["因信称义", "称义"])
    }

    @Test func strictPromptAddsFaithfulnessAndScriptureRules() {
        let prompt = HyMT2PromptBuilder.prompt(
            source: "约翰福音三章十六节",
            targetLanguage: "en",
            terms: [],
            strict: true
        )

        #expect(prompt.contains("without summarizing, adding, or omitting"))
        #expect(prompt.contains("John 3:16"))
        #expect(prompt.contains("ONLY output the translated result"))
    }

    @Test func sanitizesNewlinesInsideTerminology() {
        let prompt = HyMT2PromptBuilder.prompt(
            source: "圣灵",
            targetLanguage: "en",
            terms: [TranslationTerm(source: "圣\n灵", target: "Holy\nSpirit")],
            strict: false
        )

        #expect(prompt.contains("圣 灵 translates to Holy Spirit"))
    }
}
