import Foundation
import SettingsAPI
import SettingsUserDefaults
import Testing

@Suite struct UserDefaultsSettingsStoreTests {
    @Test func displayLanguagePersistsAcrossStoreInstances() async throws {
        let suiteName = "LiveChurchTranslationTests.\(UUID().uuidString)"
        let key = "display-language-settings"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstStore = UserDefaultsSettingsStore(suiteName: suiteName, key: key)
        try await firstStore.save(
            AppSettings(displayLanguage: .traditionalChinese)
        )

        let restored = try await UserDefaultsSettingsStore(
            suiteName: suiteName,
            key: key
        ).load()

        #expect(restored.displayLanguage == .traditionalChinese)
        #expect(restored.translationMode == .mandarinToEnglish)
    }
}
