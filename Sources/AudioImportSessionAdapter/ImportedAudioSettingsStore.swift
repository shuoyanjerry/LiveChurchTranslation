import SettingsAPI

public struct ImportedAudioSettingsStore: SettingsStore {
    private let base: any SettingsStore
    private let mode: TranslationMode

    public init(base: any SettingsStore, mode: TranslationMode) {
        self.base = base
        self.mode = mode
    }

    public func load() async throws -> AppSettings {
        var settings = try await base.load()
        settings.translationMode = mode
        return settings
    }

    public func save(_ settings: AppSettings) async throws {
        var value = settings
        value.translationMode = try await base.load().translationMode
        try await base.save(value)
    }
}
