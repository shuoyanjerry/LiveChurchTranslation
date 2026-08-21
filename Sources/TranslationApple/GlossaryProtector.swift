import Foundation
import TranslationAPI

struct ProtectedTranslationInput: Sendable {
    let source: String
    let inlineFallbackSource: String
    let replacements: [ProtectedTerm]
}

struct ProtectedTerm: Sendable {
    let marker: String
    let target: String
}

enum GlossaryProtector {
    static func protect(_ text: String, terms: [TranslationTerm]) -> ProtectedTranslationInput {
        let applicable =
            terms
            .filter { !$0.source.isEmpty && text.localizedCaseInsensitiveContains($0.source) }
            .sorted { $0.source.count > $1.source.count }
        var protected = text
        var fallback = text
        var replacements: [ProtectedTerm] = []

        for (index, term) in applicable.enumerated() {
            let marker = "LCTGLOSSARY\(index)"
            protected = protected.replacingOccurrences(of: term.source, with: " \(marker) ")
            fallback = fallback.replacingOccurrences(of: term.source, with: " \(term.target) ")
            replacements.append(ProtectedTerm(marker: marker, target: term.target))
        }
        return ProtectedTranslationInput(
            source: protected,
            inlineFallbackSource: fallback,
            replacements: replacements
        )
    }

    static func restore(_ text: String, input: ProtectedTranslationInput) -> String? {
        var restored = text
        for replacement in input.replacements {
            let pattern = markerPattern(replacement.marker)
            guard
                let expression = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                )
            else { return nil }
            let range = NSRange(restored.startIndex..., in: restored)
            if expression.firstMatch(in: restored, range: range) != nil {
                restored = expression.stringByReplacingMatches(
                    in: restored,
                    range: range,
                    withTemplate: replacement.target
                )
            } else if !restored.localizedCaseInsensitiveContains(replacement.target) {
                return nil
            }
            restored = canonicalize(replacement.target, in: restored)
        }
        return restored.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func markerPattern(_ marker: String) -> String {
        marker.map { character in
            character.isNumber ? "\\s*\(character)\\s*" : String(character)
        }.joined()
    }

    private static func canonicalize(_ target: String, in text: String) -> String {
        guard let range = text.range(of: target, options: [.caseInsensitive]) else { return text }
        var result = text
        result.replaceSubrange(range, with: target)
        return result
    }
}
