public struct AppSettings: Codable, Equatable, Sendable {
    public var selectedAudioDeviceID: String?
    public var asrModelID: String
    public var readerFontSize: Double
    public var showSourceText: Bool

    public init(
        selectedAudioDeviceID: String? = nil,
        asrModelID: String = "qwen3-asr-0.6b-int8-2026-03-25",
        readerFontSize: Double = 28,
        showSourceText: Bool = true
    ) {
        self.selectedAudioDeviceID = selectedAudioDeviceID
        self.asrModelID = asrModelID
        self.readerFontSize = readerFontSize
        self.showSourceText = showSourceText
    }

    public static let defaults = AppSettings()
}

public protocol SettingsStore: Sendable {
    func load() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
}
