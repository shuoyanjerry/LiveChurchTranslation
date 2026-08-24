import Foundation
import SettingsAPI
import Testing

@Suite struct AppSettingsBoundsTests {
    @Test func clampsReaderFontSizeAtConstructionAndDecoding() throws {
        #expect(AppSettings(readerFontSize: 200).readerFontSize == 44)
        #expect(AppSettings(readerFontSize: 2).readerFontSize == 18)
        #expect(AppSettings(readerFontSize: .nan).readerFontSize == 28)

        let oversized = Data(#"{"readerFontSize":1000}"#.utf8)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: oversized)
        #expect(decoded.readerFontSize == 44)
    }

    @Test func timestampPreferenceDefaultsOnAndSurvivesPersistence() throws {
        let legacy = Data(#"{"readerFontSize":28}"#.utf8)
        let legacySettings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        #expect(legacySettings.showTimestamps)

        let hidden = AppSettings(showTimestamps: false)
        let roundTripped = try JSONDecoder().decode(
            AppSettings.self,
            from: JSONEncoder().encode(hidden)
        )
        #expect(!roundTripped.showTimestamps)
    }
}
