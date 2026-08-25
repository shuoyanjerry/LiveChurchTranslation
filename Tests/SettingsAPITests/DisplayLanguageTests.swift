import Foundation
import SettingsAPI
import Testing

@Suite struct DisplayLanguageTests {
    @Test func simplifiedChineseIsTheStableDefault() throws {
        let legacyData = Data(#"{"readerFontSize":28}"#.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: legacyData)

        #expect(AppSettings.defaults.displayLanguage == .simplifiedChinese)
        #expect(settings.displayLanguage == .simplifiedChinese)
        #expect(DisplayLanguage.allCases == [.simplifiedChinese, .traditionalChinese])
    }

    @Test func interfaceTextUsesMechanicalCharacterConversion() {
        let source = "显示语言 Live 123 https://example.com"

        #expect(DisplayLanguage.simplifiedChinese.interfaceText(source) == source)
        #expect(
            DisplayLanguage.traditionalChinese.interfaceText(source)
                == "顯示語言 Live 123 https://example.com"
        )
        #expect(
            DisplayLanguage.traditionalChinese.interfaceText("正在聆听与翻译")
                == "正在聆聽與翻譯"
        )
    }

    @Test func displayLanguageSurvivesSettingsRoundTrip() throws {
        let settings = AppSettings(
            translationMode: .englishToSimplifiedChinese,
            displayLanguage: .traditionalChinese
        )

        let decoded = try JSONDecoder().decode(
            AppSettings.self,
            from: JSONEncoder().encode(settings)
        )

        #expect(decoded == settings)
        #expect(decoded.translationMode.targetLanguageTag == "zh-Hans")
    }

    @Test func legacyTranslationModeFallsBackToExistingSimplifiedChineseMode() throws {
        let data = Data(
            #"{"translationMode":"englishToTraditionalChinese","displayLanguage":"zh-Hant"}"#.utf8
        )

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.translationMode == .englishToSimplifiedChinese)
        #expect(settings.displayLanguage == .traditionalChinese)
        #expect(TranslationMode.allCases == [.mandarinToEnglish, .englishToSimplifiedChinese])
    }

    @Test func invalidTranslationModeStillFailsDecoding() {
        let data = Data(#"{"translationMode":"unsupported"}"#.utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppSettings.self, from: data)
        }
    }

    @Test func historicalTraditionalTargetResumesAsExistingSimplifiedChineseMode() {
        let mode = TranslationMode(
            sourceLanguageTag: "en",
            targetLanguageTag: "zh-Hant"
        )

        #expect(mode == .englishToSimplifiedChinese)
        #expect(mode?.targetLanguageTag == "zh-Hans")
    }
}
