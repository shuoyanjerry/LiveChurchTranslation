import Foundation

extension HyMT2FidelityValidator {
    static func plausibleLength(
        _ target: String,
        source: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> Bool {
        guard !target.isEmpty else { return false }
        let sourceCount = max(1, source.count)
        guard target.count <= sourceCount * 10 + 80 else { return false }

        let sourceIsChinese = sourceLanguage.lowercased().hasPrefix("zh")
        let targetIsChinese = targetLanguage.lowercased().hasPrefix("zh")
        if sourceIsChinese, !targetIsChinese {
            return preservesEnoughContent(target, source: source, divisor: 5)
        }
        if !sourceIsChinese, targetIsChinese {
            return preservesEnoughContent(target, source: source, divisor: 3)
        }
        return target.count >= max(1, sourceCount / 5)
    }

    private static func preservesEnoughContent(
        _ target: String,
        source: String,
        divisor: Int
    ) -> Bool {
        let sourceUnits = contentUnitCount(in: source)
        guard sourceUnits >= 24 else { return true }
        let minimumTargetUnits = (sourceUnits - 1) / divisor + 1
        return contentUnitCount(in: target) >= minimumTargetUnits
    }

    private static func contentUnitCount(in text: String) -> Int {
        hanCharacterCount(in: text) + latinWordCount(in: text)
    }

    private static func hanCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { count, scalar in
            if scalar.properties.isIdeographic { count += 1 }
        }
    }

    private static func latinWordCount(in text: String) -> Int {
        var count = 0
        var isInsideWord = false
        for scalar in text.unicodeScalars {
            if isLatinLetter(scalar) {
                if !isInsideWord { count += 1 }
                isInsideWord = true
            } else if scalar != "'", scalar != "’" {
                isInsideWord = false
            }
        }
        return count
    }

    private static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
            true
        default:
            false
        }
    }

    static func containsMetaText(_ target: String) -> Bool {
        HyMT2MetaText.occurs(in: target)
            || HyMT2MetaText.normalized(target).lowercased().hasPrefix(
                "reference the following translations"
            )
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
