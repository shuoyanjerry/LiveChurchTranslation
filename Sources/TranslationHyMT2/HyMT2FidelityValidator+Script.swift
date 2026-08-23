import Foundation

extension HyMT2FidelityValidator {
    static func plausibleLength(_ target: String, source: String) -> Bool {
        guard !target.isEmpty else { return false }
        let sourceCount = max(1, source.count)
        return target.count >= max(1, sourceCount / 5)
            && target.count <= sourceCount * 10 + 80
    }

    static func containsMetaText(_ target: String) -> Bool {
        let lower = target.lowercased()
        let prefixes = [
            "here is the translation", "the translation is", "translation:",
            "translated result:", "as an ai", "i cannot translate", "source text:",
            "reference the following translations",
            "以下是翻译", "翻译如下", "译文：", "作为一个ai", "原文：",
        ]
        return prefixes.contains(where: lower.hasPrefix)
    }

    static func hasUnexpectedScript(
        _ target: String,
        source: String,
        targetLanguage: String
    ) -> Bool {
        let containsHan = target.unicodeScalars.contains { scalar in
            scalar.properties.isIdeographic
                || chinesePunctuation.contains(Character(String(scalar)))
        }
        guard targetLanguage.lowercased().hasPrefix("zh") else { return containsHan }
        guard containsHan else { return source.rangeOfCharacter(from: .letters) != nil }
        if target.contains("上帝") || containsJapaneseOrKoreanScript(target) { return true }
        let simplified = target.applyingTransform(
            StringTransform("Traditional-Simplified"),
            reverse: false
        )
        return simplified.map { $0 != target } ?? false
    }

    private static func containsJapaneseOrKoreanScript(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF, 0x31F0...0x31FF,
                0x1100...0x11FF, 0x3130...0x318F, 0xA960...0xA97F,
                0xAC00...0xD7AF, 0xD7B0...0xD7FF:
                true
            default:
                false
            }
        }
    }

    private static let chinesePunctuation = Set<Character>([
        "，", "。", "；", "：", "！", "？", "、", "《", "》", "「", "」", "『", "』",
    ])
}
