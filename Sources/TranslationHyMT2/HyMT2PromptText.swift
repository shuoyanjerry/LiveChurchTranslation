import Foundation
import TranslationAPI

enum HyMT2PromptText {
    static func backgroundSection(
        _ context: [TranslationContextEntry],
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) -> String {
        let pairs = context.enumerated().map { index, entry in
            "Prior pair \(index + 1) — \(backgroundLanguageName(sourceLanguage)): "
                + "\(quotedSingleLine(entry.sourceText))\n"
                + "Prior pair \(index + 1) — \(backgroundLanguageName(targetLanguage)): "
                + quotedSingleLine(entry.targetText)
        }
        return [
            HyMT2PromptControlDelimiter.backgroundOpening,
            pairs.joined(separator: "\n"),
            HyMT2PromptControlDelimiter.backgroundClosing,
        ].joined(separator: "\n")
    }

    static func currentSourceSection(
        _ source: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        taskInstruction(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) + "\n"
            + "\(HyMT2PromptControlDelimiter.currentSourceOpening)\n"
            + "\(source)\n"
            + HyMT2PromptControlDelimiter.currentSourceClosing
    }

    static func singleLine(_ value: String) -> String {
        value.split(whereSeparator: \Character.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func quotedSingleLine(_ value: String) -> String {
        String(reflecting: singleLine(value))
    }

    private static func taskInstruction(
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        if sourceLanguage.lowercased().hasPrefix("zh") {
            return "请将 <CURRENT_SOURCE> 内的讲道文本逐句完整、忠实地翻译为"
                + "\(chineseLanguageName(targetLanguage))，不得概括、添加或漏译。"
                + "不要输出 CURRENT_SOURCE 标签。只输出译文，不要解释。"
        }
        return "Translate every clause inside CURRENT SOURCE faithfully into "
            + "\(languageName(targetLanguage)) without summarizing, adding, or omitting. "
            + "Do not output the CURRENT SOURCE tags. Output only the translation."
    }

    private static func languageName(_ code: String) -> String {
        switch code.lowercased() {
        case "en", "en-us", "en-gb": "English"
        case "zh", "zh-hans", "zh-cn": "Simplified Chinese"
        default: code
        }
    }

    private static func chineseLanguageName(_ code: String) -> String {
        switch code.lowercased() {
        case "en", "en-us", "en-gb": "英语"
        case "zh", "zh-hans", "zh-cn": "简体中文"
        default: code
        }
    }

    private static func backgroundLanguageName(_ code: String) -> String {
        code.lowercased().hasPrefix("zh") ? "Chinese" : languageName(code)
    }
}
