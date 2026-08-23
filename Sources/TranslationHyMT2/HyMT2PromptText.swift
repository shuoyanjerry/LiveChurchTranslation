import Foundation
import TranslationAPI

enum HyMT2PromptText {
    static func backgroundSection(
        _ context: [TranslationContextEntry],
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) -> String {
        let pairs = context.enumerated().map { index, entry in
            "Prior pair \(index + 1):\n"
                + "\(backgroundLanguageName(sourceLanguage)): "
                + "\(quotedSingleLine(entry.sourceText))\n"
                + "\(backgroundLanguageName(targetLanguage)): "
                + quotedSingleLine(entry.targetText)
        }
        return [
            HyMT2PromptControlDelimiter.backgroundOpening,
            "These are prior, finalized, validator-approved translation pairs.",
            "Use them only to resolve references and keep terminology consistent.",
            "Do not translate, output, copy, repeat, or summarize any background text.",
            pairs.joined(separator: "\n"),
            HyMT2PromptControlDelimiter.backgroundClosing,
        ].joined(separator: "\n")
    }

    static func currentSourceSection(
        _ source: String,
        targetLanguage: String
    ) -> String {
        "Translate only the text inside CURRENT SOURCE into "
            + "\(languageName(targetLanguage)). You must ONLY output the translated result "
            + "for CURRENT SOURCE without any additional explanation.\n"
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

    private static func languageName(_ code: String) -> String {
        switch code.lowercased() {
        case "en", "en-us", "en-gb": "English"
        case "zh", "zh-hans", "zh-cn": "Simplified Chinese"
        default: code
        }
    }

    private static func backgroundLanguageName(_ code: String) -> String {
        code.lowercased().hasPrefix("zh") ? "Chinese" : languageName(code)
    }
}
