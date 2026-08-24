import Foundation
import GlossaryAPI
import SettingsAPI
import Testing
@testable import SessionManagement

@Suite struct EnglishTranslationModeTests {
    @Test func legacySettingsMigrateToTheOriginalDirection() throws {
        let data = Data(
            #"{"asrModelID":"legacy","readerFontSize":30,"showSourceText":false}"#.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.translationMode == .mandarinToEnglish)
        #expect(settings.readerFontSize == 30)
        #expect(!settings.showSourceText)
    }

    @Test func englishModeFlowsThroughRecognitionTranslationAndSourceCommit() async throws {
        let harness = SessionTestHarness(
            recognizedText: "We receive justification by faith through grace.",
            translationMode: .englishToSimplifiedChinese
        )

        _ = try await harness.run()

        let asrRequest = try #require(await harness.asr.receivedRequests().first)
        #expect(asrRequest.languageCode == "en")
        #expect(asrRequest.contextPrompt.contains("justification by faith"))

        let translation = try #require(await harness.translator.receivedRequests().first)
        #expect(translation.sourceLanguage == "en")
        #expect(translation.targetLanguage == "zh-Hans")
        #expect(
            translation.glossary.contains {
                $0.source == "justification by faith" && $0.target == "因信称义"
            }
        )

        let session = try #require(await harness.store.begunSessions().first)
        #expect(session.sourceLanguage == "en")
        #expect(session.targetLanguage == "zh-Hans")
    }

    @Test func englishModeBypassesMandarinNormalizationForCodeSwitching() async throws {
        let source = "The speaker quoted 因信生义 while explaining the recognition error."
        let harness = SessionTestHarness(
            recognizedText: source,
            translationMode: .englishToSimplifiedChinese
        )

        _ = try await harness.run()

        let request = try #require(await harness.translator.receivedRequests().first)
        let entry = try #require(await harness.store.appendedEntries().first)
        #expect(request.sourceText == source)
        #expect(entry.sourceText == source)
        #expect(entry.sourceCorrections.isEmpty)
    }

    @Test func requiredEnglishHotwordsOutrankLongPreferredTerms() {
        let preferred = (0..<60).map { index in
            GlossaryEntry(
                source: "可选词\(index)",
                target: "optional-theological-expression-\(index)"
            )
        }
        let prayer = GlossaryEntry(
            source: "祷告",
            target: "prayer",
            targetVariants: ["pray", "prays", "praying"],
            enforcement: .required
        )

        let prompt = ASRContextTermSelector.prompt(
            from: preferred + [prayer],
            mode: .englishToSimplifiedChinese
        )

        #expect(prompt.split(separator: ",").count <= 18)
        #expect(prompt.contains("prayer"))
        #expect(prompt.contains("praying"))
        #expect(!prompt.contains("optional-theological-expression"))
    }

    @Test func mandarinHotwordsUseABoundedTheologicalCore() {
        let prompt = ASRContextTermSelector.prompt(
            from: DefaultGlossary.entries,
            mode: .mandarinToEnglish
        )

        #expect(
            prompt
                == "麦基洗德,撒冷,亚伯拉罕,至高神,祭司,基督耶稣,救赎,恩典,"
                + "本乎恩典,因着信,称义,成圣,主耶稣基督,圣灵,父子圣灵"
        )
    }

    @Test func mandarinHotwordsReserveCapacityForRequiredCustomTerms() {
        let prompt = ASRContextTermSelector.prompt(
            from: DefaultGlossary.entries + [
                GlossaryEntry(
                    source: "尼布甲尼撒",
                    target: "Nebuchadnezzar",
                    enforcement: .required
                ),
                GlossaryEntry(source: "提摩太", target: "Timothy", enforcement: .required),
                GlossaryEntry(source: "约伯", target: "Job", enforcement: .required),
            ],
            mode: .mandarinToEnglish
        )

        #expect(prompt.split(separator: ",").count == 18)
        #expect(prompt.hasSuffix("父子圣灵,约伯,提摩太,尼布甲尼撒"))
    }

    @Test func englishHotwordCoreRemainsStable() {
        let prompt = ASRContextTermSelector.prompt(
            from: DefaultGlossary.entries,
            mode: .englishToSimplifiedChinese
        )

        #expect(
            prompt
                == "salvation,grace,justification,sanctification,the Holy Spirit,the Trinity,"
                + "resurrection,atonement,repentance,prayer,pray,prays,praying,praise,praises,"
                + "praising,church,gracious"
        )
    }

    @Test func englishSavedAcceptsNaturalChineseTargetVariant() async throws {
        let harness = SessionTestHarness(
            recognizedText: "We are saved by grace.",
            translationMode: .englishToSimplifiedChinese
        )

        _ = try await harness.run()

        let request = try #require(await harness.translator.receivedRequests().first)
        let saved = try #require(request.glossary.first { $0.source == "salvation" })
        #expect(saved.target == "救恩")
        #expect(saved.acceptedTargets.contains("得救"))
        #expect(saved.requirement == .required)
    }
}
