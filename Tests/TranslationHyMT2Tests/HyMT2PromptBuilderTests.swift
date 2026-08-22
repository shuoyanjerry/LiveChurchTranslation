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
        #expect(prompt.contains("<CURRENT_SOURCE>\n\(source)\n</CURRENT_SOURCE>"))
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

    @Test func matchesSemanticSourceAliasWithoutRewritingASRText() {
        let term = TranslationTerm(
            source: "洗礼",
            target: "baptism",
            sourceAliases: ["受浸"]
        )

        let matched = TranslationTermMatcher.matched(
            in: "今天有三位弟兄受浸",
            from: [term],
            limit: 2
        )

        #expect(matched == [term])
    }
}

@Suite struct HyMT2PromptPolicyAndContextTests {
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

    @Test func labelsPriorPairsAsBackgroundInsteadOfCurrentInput() {
        let context = [
            TranslationContextEntry(
                sourceText: "这位姊妹分享了见证。",
                targetText: "The sister shared her testimony."
            )
        ]
        let source = "她感谢神的恩典。"

        let prompt = HyMT2PromptBuilder.prompt(
            source: source,
            targetLanguage: "en",
            terms: [],
            context: context,
            strict: false
        )

        #expect(prompt.contains("BACKGROUND FOR DISAMBIGUATION ONLY"))
        #expect(prompt.contains("Chinese: \"这位姊妹分享了见证。\""))
        #expect(prompt.contains("English: \"The sister shared her testimony.\""))
        #expect(prompt.contains("Do not translate, output, copy, repeat, or summarize"))
        #expect(prompt.contains("<CURRENT_SOURCE>\n\(source)\n</CURRENT_SOURCE>"))
        #expect(
            prompt.range(of: "END BACKGROUND")!.upperBound
                < prompt.range(of: "<CURRENT_SOURCE>")!.lowerBound)
    }

    @Test func includesOnlyTwoNewestSuppliedContextPairs() {
        let context = [
            TranslationContextEntry(sourceText: "第一句", targetText: "First"),
            TranslationContextEntry(sourceText: "第二句", targetText: "Second"),
            TranslationContextEntry(sourceText: "第三句", targetText: "Third"),
        ]

        let prompt = HyMT2PromptBuilder.prompt(
            source: "现在这句",
            targetLanguage: "en",
            terms: [],
            context: context,
            strict: false
        )

        #expect(!prompt.contains("第一句"))
        #expect(prompt.contains("第二句"))
        #expect(prompt.contains("第三句"))
        #expect(prompt.contains("Prior pair 1"))
        #expect(prompt.contains("Prior pair 2"))
        #expect(!prompt.contains("Prior pair 3"))
    }

    @Test func translationRequestKeepsImmutableContext() {
        let context = TranslationContextEntry(
            sourceText: "神赐恩典。",
            targetText: "God gives grace."
        )

        let request = TranslationRequest(
            sourceText: "我们感谢祂。",
            glossary: [],
            context: [context]
        )

        #expect(request.context == [context])
    }
}
