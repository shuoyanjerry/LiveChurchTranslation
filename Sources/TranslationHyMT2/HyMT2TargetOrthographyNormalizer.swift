import Foundation

enum HyMT2TargetOrthographyNormalizer {
    static func normalize(_ target: String, language: String) -> String {
        guard language.lowercased().hasPrefix("zh") else { return target }
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
}
