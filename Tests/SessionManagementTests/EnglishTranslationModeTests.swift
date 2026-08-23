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

    @Test func englishModeFlowsThroughRecognitionTranslationAndPersistence() async throws {
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
}
