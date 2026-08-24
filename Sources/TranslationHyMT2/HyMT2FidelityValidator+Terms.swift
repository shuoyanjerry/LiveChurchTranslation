import Foundation
import TranslationAPI

extension HyMT2FidelityValidator {
    static func missingTerms(
        in target: String,
        required: [TranslationTerm]
    ) -> [OutputValidationIssue] {
        required.compactMap { term in
            guard term.requirement == .required else { return nil }
            let accepted = [term.target] + term.acceptedTargets
            let found = accepted.contains { containsTerm($0, in: target) }
            return found ? nil : .missingTerm(term.target)
        }
    }

    private static func containsTerm(_ candidate: String, in text: String) -> Bool {
        let candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        var searchStart = text.startIndex
        while searchStart < text.endIndex {
            let remaining = searchStart..<text.endIndex
            guard
                let match = text.range(
                    of: candidate,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: remaining
                )
            else { return false }
            if hasValidTermBoundaries(match, candidate: candidate, in: text) { return true }
            searchStart = text.index(after: match.lowerBound)
        }
        return false
    }

    private static func hasValidTermBoundaries(
        _ match: Range<String.Index>,
        candidate: String,
        in text: String
    ) -> Bool {
        let first = candidate.first.map(isLatinWordCharacter) == true
        let last = candidate.last.map(isLatinWordCharacter) == true
        let touchesPreviousWord =
            first && match.lowerBound > text.startIndex
            && isLatinWordCharacter(text[text.index(before: match.lowerBound)])
        let touchesNextWord =
            last && match.upperBound < text.endIndex
            && isLatinWordCharacter(text[match.upperBound])
        return !touchesPreviousWord && !touchesNextWord
    }

    private static func isLatinWordCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0030...0x0039, 0x0041...0x005A, 0x0061...0x007A, 0x00C0...0x024F:
                true
            default:
                false
            }
        }
    }

    static func missingNumbers(
        in target: String,
        source: String
    ) -> [OutputValidationIssue] {
        let sourceNumbers = digitRuns(in: source)
        var remaining = digitRuns(in: target)
        return sourceNumbers.compactMap { number in
            guard let index = remaining.firstIndex(of: number) else {
                return .missingNumber(number)
            }
            remaining.remove(at: index)
            return nil
        }
    }

    static func containsScriptureReference(_ text: String, language: String) -> Bool {
        if !matches(pattern: #"\d+\s*:\s*\d+"#, in: text).isEmpty { return true }
        if language.lowercased().hasPrefix("zh") {
            return !matches(
                pattern: #"[0-9零〇一二两三四五六七八九十百千]+章[0-9零〇一二两三四五六七八九十百千]+节"#,
                in: text
            ).isEmpty
        }
        return text.localizedCaseInsensitiveContains("chapter")
            && text.localizedCaseInsensitiveContains("verse")
    }

    private static func digitRuns(in text: String) -> [String] {
        matches(pattern: #"\d+"#, in: text)
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
