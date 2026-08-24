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

        #expect(prompt.contains("因信称义 翻译成 justification by faith"))
        #expect(prompt.contains("恩典 翻译成 grace"))
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

    @Test func longerLexicalCompoundsSuppressMisleadingSingleCharacterTerm() {
        let god = TranslationTerm(source: "神", target: "God")
        let nerve = TranslationTerm(
            source: "神经",
            target: "nerve",
            acceptedTargets: ["nerves", "neural"]
        )
        let seminary = TranslationTerm(source: "神学院", target: "seminary")

        let matched = TranslationTermMatcher.matched(
            in: "麻风病人的神经受伤，宣教士也建立了神学院。",
            from: [god, nerve, seminary],
            limit: 64
        )

        #expect(matched == [seminary, nerve])
        #expect(!matched.contains(god))
    }
}
