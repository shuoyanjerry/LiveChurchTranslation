import Foundation

enum HyMT2MetaText {
    static let removablePrefixes = [
        "here is the translation", "the translation is", "translation:",
        "translated result:", "以下是翻译", "翻译如下", "译文:",
    ]

    private static let sourceLabelPrefixes = [
        "source text:", "original text:", "原文:",
    ]
    private static let aiPrefixes = [
        "as an ai", "as an artificial intelligence", "作为一个ai", "作为ai", "作为人工智能",
    ]
    private static let refusalLeadIns = [
        "i ", "i'm ", "i am ", "sorry", "as an ai", "as an artificial intelligence",
        "我", "无法", "不能", "抱歉", "很抱歉", "对不起", "作为一个ai", "作为人工智能",
    ]
    private static let refusalSignals = [
        "cannot translate", "can't translate", "unable to translate",
        "cannot help translate", "can't help translate", "不能翻译", "无法翻译",
        "不能帮助翻译", "无法提供翻译",
    ]

    static func normalized(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"\p{Cf}"#,
            with: "",
            options: .regularExpression
        ).precomposedStringWithCompatibilityMapping
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func occurs(in value: String) -> Bool {
        let inspected = inspection(value)
        return (removablePrefixes + sourceLabelPrefixes + aiPrefixes).contains(
            where: inspected.hasPrefix
        ) || isRefusalOpening(inspected)
    }

    static func blocksPresentation(_ value: String, source: String) -> Bool {
        let target = inspection(value)
        let source = inspection(source)
        if sourceLabelPrefixes.contains(where: target.hasPrefix) {
            return !sourceLabelPrefixes.contains { source.contains($0) }
        }
        if aiPrefixes.contains(where: target.hasPrefix) {
            return !aiPrefixes.contains { source.contains($0) }
        }
        if isRefusalOpening(target) {
            return !refusalSignals.contains { source.contains($0) }
        }
        return false
    }

    static func isProbableSourceEcho(
        target: String,
        source: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> Bool {
        guard primaryLanguage(sourceLanguage) != primaryLanguage(targetLanguage) else { return false }
        let sourceKey = echoKey(source)
        guard !sourceKey.isEmpty,
            sourceKey == echoKey(target),
            source.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) })
        else { return false }
        return true
    }

    private static func inspection(_ value: String) -> String {
        normalized(value).lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
    }

    private static func isRefusalOpening(_ value: String) -> Bool {
        let opening = value.trimmingCharacters(
            in: .whitespacesAndNewlines.union(
                CharacterSet(charactersIn: "\"'“”‘’「」『』()（）")
            )
        )
        guard refusalLeadIns.contains(where: opening.hasPrefix) else { return false }
        let head = String(opening.prefix(120))
        return refusalSignals.contains { head.contains($0) }
    }

    private static func echoKey(_ value: String) -> String {
        inspection(value).replacingOccurrences(
            of: #"[\p{P}\p{S}\s]+"#,
            with: "",
            options: .regularExpression
        )
    }

    private static func primaryLanguage(_ value: String) -> Substring {
        value.lowercased().split(separator: "-").first ?? ""
    }
}
