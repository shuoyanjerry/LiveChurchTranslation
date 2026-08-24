import AudioImportSessionAdapter
import SettingsAPI
import Testing

@Suite struct ImportedAudioSettingsStoreTests {
    @Test func overridesOnlyTheImportedSessionDirection() async throws {
        let base = ImportedSettingsStoreStub(
            AppSettings(
                translationMode: .mandarinToEnglish,
                readerFontSize: 28
            )
        )
        let imported = ImportedAudioSettingsStore(
            base: base,
            mode: .englishToSimplifiedChinese
        )

        let loaded = try await imported.load()
        #expect(loaded.translationMode == .englishToSimplifiedChinese)

        try await imported.save(
            AppSettings(
                translationMode: .englishToSimplifiedChinese,
                readerFontSize: 36
            )
        )
        let persisted = await base.load()
        #expect(persisted.translationMode == .mandarinToEnglish)
        #expect(persisted.readerFontSize == 36)
    }
}

private actor ImportedSettingsStoreStub: SettingsStore {
    private var value: AppSettings

    init(_ value: AppSettings) {
        self.value = value
    }

    func load() -> AppSettings { value }
    func save(_ settings: AppSettings) { value = settings }
}
