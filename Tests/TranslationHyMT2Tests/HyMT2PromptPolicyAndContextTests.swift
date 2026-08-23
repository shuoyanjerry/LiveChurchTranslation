import ScriptureAPI
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PromptPolicyAndContextTests {
    @Test func strictPromptAddsFaithfulnessAndScriptureRules() {
        let prompt = HyMT2PromptBuilder.prompt(
            source: "约翰福音三章十六节",
            targetLanguage: "en",
            terms: [],
            strict: true
        )

        #expect(prompt.contains("without summarizing, adding, or omitting"))
        let edition = ScriptureEditionPair.production.english
        #expect(prompt.contains(edition.fullName))
        #expect(prompt.contains(edition.editionLabel))
        #expect(prompt.contains(ScriptureEditionPair.terminologyBaselineNotice))
        #expect(prompt.contains("John 3:16"))
        #expect(prompt.contains("ONLY output the translated result"))
    }

    @Test func initialEnglishToChinesePromptPinsShenEditionWithoutInventingText() {
        let prompt = HyMT2PromptBuilder.prompt(
            source: "John 3:16 says that God loved the world.",
            targetLanguage: "zh-Hans",
            sourceLanguage: "en",
            terms: [],
            strict: false
        )

        let edition = ScriptureEditionPair.production.simplifiedChinese
        #expect(prompt.contains(edition.abbreviation))
        #expect(prompt.contains(edition.fullName))
        #expect(prompt.contains(edition.officialEditionReference))
        #expect(prompt.contains(ScriptureEditionPair.terminologyBaselineNotice))
        #expect(prompt.contains("use 神 rather than 上帝"))
        #expect(prompt.contains("allow 他 or 祂 according to context"))
        #expect(prompt.contains("never reconstruct or invent verse text"))
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
