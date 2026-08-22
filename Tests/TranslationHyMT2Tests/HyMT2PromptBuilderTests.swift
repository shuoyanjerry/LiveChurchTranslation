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
