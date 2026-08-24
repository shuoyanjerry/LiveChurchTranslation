import Foundation

enum HyMT2TargetOrthographyNormalizer {
    static func normalize(_ target: String, language: String) -> String {
        guard language.lowercased().hasPrefix("zh") else {
            return normalizeEnglishPunctuation(target)
        }
        let simplified =
            target.applyingTransform(
                StringTransform("Traditional-Simplified"),
                reverse: false
            ) ?? target
        return
            simplified
            .replacingOccurrences(of: "上帝", with: "神")
            .replacingOccurrences(of: "의", with: "的")
            .replacingOccurrences(
                of: #"(?<=\p{Han})[ \t]+(?=\p{Han})"#,
                with: "",
                options: .regularExpression
            )
    }

    private static func normalizeEnglishPunctuation(_ target: String) -> String {
        let spacedReplacements = [
            ("，", ", "), ("。", ". "), ("；", "; "), ("：", ": "),
            ("！", "! "), ("？", "? "), ("、", ", "),
        ]
        var mapped = spacedReplacements.reduce(target) { value, replacement in
            value.replacingOccurrences(
                of: replacement.0 + #"[ \t]*"#,
                with: replacement.1,
                options: .regularExpression
            )
        }
        for punctuation in ["《", "》", "「", "」", "『", "』"] {
            mapped = mapped.replacingOccurrences(of: punctuation, with: "\"")
        }
        return mapped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
