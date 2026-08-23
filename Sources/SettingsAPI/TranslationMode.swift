public enum TranslationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case mandarinToEnglish
    case englishToSimplifiedChinese

    public var id: String { rawValue }

    public var sourceRecognitionCode: String {
        switch self {
        case .mandarinToEnglish: "zh"
        case .englishToSimplifiedChinese: "en"
        }
    }

    public var sourceLanguageTag: String {
        switch self {
        case .mandarinToEnglish: "zh-Hans"
        case .englishToSimplifiedChinese: "en"
        }
    }

    public var targetLanguageTag: String {
        switch self {
        case .mandarinToEnglish: "en"
        case .englishToSimplifiedChinese: "zh-Hans"
        }
    }

    public var sourceDisplayName: String {
        switch self {
        case .mandarinToEnglish: "普通话"
        case .englishToSimplifiedChinese: "英语"
        }
    }

    public var targetDisplayName: String {
        switch self {
        case .mandarinToEnglish: "英语"
        case .englishToSimplifiedChinese: "简体中文"
        }
    }

    public var displayName: String {
        "\(sourceDisplayName) → \(targetDisplayName)"
    }

    public var compactDisplayName: String {
        switch self {
        case .mandarinToEnglish: "中 → 英"
        case .englishToSimplifiedChinese: "英 → 中"
        }
    }

    public init?(sourceLanguageTag: String, targetLanguageTag: String) {
        switch (sourceLanguageTag.lowercased(), targetLanguageTag.lowercased()) {
        case ("zh-hans", "en"), ("zh", "en"):
            self = .mandarinToEnglish
        case ("en", "zh-hans"), ("en-us", "zh-hans"), ("en-gb", "zh-hans"):
            self = .englishToSimplifiedChinese
        default:
            return nil
        }
    }
}
