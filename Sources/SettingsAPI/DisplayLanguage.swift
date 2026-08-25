import Foundation

public enum DisplayLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    public var id: String { rawValue }

    public var autonym: String {
        switch self {
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    public func interfaceText(_ simplifiedText: String) -> String {
        guard self == .traditionalChinese else { return simplifiedText }
        return simplifiedText.applyingTransform(
            StringTransform("Hans-Hant"),
            reverse: false
        ) ?? simplifiedText
    }
}
