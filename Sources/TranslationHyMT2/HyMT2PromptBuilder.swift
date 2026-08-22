import Foundation
import TranslationAPI

enum HyMT2PromptBuilder {
    static func prompt(
        source: String,
        targetLanguage: String,
        terms: [TranslationTerm],
        context: [TranslationContextEntry] = [],
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
        sections.append(pronounRule)
        let recentContext = context.suffix(maximumContextEntries)
        if !recentContext.isEmpty {
            sections.append(backgroundSection(Array(recentContext)))
        }
        sections.append(
            currentSourceSection(source, targetLanguage: targetLanguage)
        )
        return sections.joined(separator: "\n\n")
    }

    private static let maximumContextEntries = 2

    private static let strictRules = [
        "Translate every clause faithfully without summarizing, adding, or omitting meaning.",
        "Preserve negation, names, and all numbers.",
        "Render Scripture chapter-and-verse references in conventional English numeric form",
        "(for example, John 3:16). Use required reference terms or an accepted grammatical variant.",
    ].joined(separator: " ")

    private static let pronounRule = [
        "Spoken Mandarin tā may be transcribed as 他 or 她 even when the audio is ambiguous.",
        "Use an English gendered pronoun only when explicit current or background evidence",
        "identifies the same human referent; never infer gender from a name, occupation, or stereotype.",
        "When no explicit evidence resolves it, use natural singular they instead of inventing gender.",
    ].joined(separator: " ")

    private static func backgroundSection(
        _ context: [TranslationContextEntry]
    ) -> String {
        let pairs = context.enumerated().map { index, entry in
            "Prior pair \(index + 1):\n"
                + "Chinese: \(quotedSingleLine(entry.sourceText))\n"
                + "English: \(quotedSingleLine(entry.targetText))"
        }
        return [
            "BACKGROUND FOR DISAMBIGUATION ONLY",
            "These are prior, finalized, validator-approved Chinese/English pairs.",
            "Use them only to resolve references and keep terminology consistent.",
            "Do not translate, output, copy, repeat, or summarize any background text.",
            pairs.joined(separator: "\n"),
            "END BACKGROUND",
        ].joined(separator: "\n")
    }

    private static func currentSourceSection(
        _ source: String,
        targetLanguage: String
    ) -> String {
        "Translate only the text inside CURRENT SOURCE into "
            + "\(languageName(targetLanguage)). You must ONLY output the translated result "
            + "for CURRENT SOURCE without any additional explanation.\n"
            + "<CURRENT_SOURCE>\n\(source)\n</CURRENT_SOURCE>"
    }

    private static func quotedSingleLine(_ value: String) -> String {
        String(reflecting: singleLine(value))
    }

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
