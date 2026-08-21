import Foundation
import TranslationAPI

enum HyMT2PromptBuilder {
    static func prompt(
        source: String,
        targetLanguage: String,
        terms: [TranslationTerm],
        strict: Bool
    ) -> String {
        var sections: [String] = []
        if !terms.isEmpty {
            let references = terms.map {
                "\(singleLine($0.source)) translates to \(singleLine($0.target))"
            }
            sections.append("Reference the following translations:\n\(references.joined(separator: "\n"))")
        }
        if strict {
            sections.append(strictRules)
        }
        sections.append(
            "Translate the following text into \(languageName(targetLanguage)). "
                + "Note that you must ONLY output the translated result without any additional explanation:\n"
                + source
        )
        return sections.joined(separator: "\n\n")
    }

    private static let strictRules = [
        "Translate every clause faithfully without summarizing, adding, or omitting meaning.",
        "Preserve negation, names, and all numbers.",
        "Render Scripture chapter-and-verse references in conventional English numeric form",
        "(for example, John 3:16). Use every applicable reference translation exactly.",
    ].joined(separator: " ")

    private static func singleLine(_ value: String) -> String {
        value.split(whereSeparator: \Character.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func languageName(_ code: String) -> String {
        switch code.lowercased() {
        case "en", "en-us", "en-gb": "English"
        default: code
        }
    }
}
