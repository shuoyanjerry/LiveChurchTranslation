public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedAudioDeviceID: String?
    public var asrModelID: String
    public var translationMode: TranslationMode
    public var readerFontSize: Double
    public var showSourceText: Bool

    public init(
        selectedAudioDeviceID: String? = nil,
        asrModelID: String = "qwen3-asr-0.6b-int8-2026-03-25",
        translationMode: TranslationMode = .mandarinToEnglish,
        readerFontSize: Double = 28,
        showSourceText: Bool = true
    ) {
        self.selectedAudioDeviceID = selectedAudioDeviceID
        self.asrModelID = asrModelID
        self.translationMode = translationMode
        self.readerFontSize = readerFontSize
        self.showSourceText = showSourceText
    }

    public static let defaults = AppSettings()

    private enum CodingKeys: String, CodingKey {
        case selectedAudioDeviceID, asrModelID, translationMode, readerFontSize, showSourceText
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        selectedAudioDeviceID = try values.decodeIfPresent(
            String.self,
            forKey: .selectedAudioDeviceID
        )
        asrModelID =
            try values.decodeIfPresent(String.self, forKey: .asrModelID)
            ?? Self.defaults.asrModelID
        translationMode =
            try values.decodeIfPresent(
                TranslationMode.self,
                forKey: .translationMode
            ) ?? .mandarinToEnglish
        readerFontSize =
            try values.decodeIfPresent(Double.self, forKey: .readerFontSize)
            ?? Self.defaults.readerFontSize
        showSourceText =
            try values.decodeIfPresent(Bool.self, forKey: .showSourceText)
            ?? Self.defaults.showSourceText
    }
}

public protocol SettingsStore: Sendable {
    func load() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
}
