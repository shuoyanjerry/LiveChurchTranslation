import Foundation

enum TranslationTargetTermMatcher {
    static func contains(_ term: String, in target: String) -> Bool {
        let expected = tokens(in: term)
        let observed = tokens(in: target)
        guard !expected.isEmpty, expected.count <= observed.count else { return false }
        for start in 0...(observed.count - expected.count)
        where Array(observed[start..<(start + expected.count)]) == expected {
            return true
        }
        return false
    }

    private static func tokens(in value: String) -> [String] {
        let normalized = value
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "’", with: "'")
            .lowercased()
        guard
            let expression = try? NSRegularExpression(
                pattern: #"[a-z0-9]+(?:'[a-z0-9]+)?"#
            )
        else { return [] }
        let range = NSRange(normalized.startIndex..., in: normalized)
        return expression.matches(in: normalized, range: range).compactMap { match in
            Range(match.range, in: normalized).map {
                removingPossessiveSuffix(from: String(normalized[$0]))
            }
        }
    }

    private static func removingPossessiveSuffix(from token: String) -> String {
        guard token.count > 2, token.hasSuffix("'s") else { return token }
        return String(token.dropLast(2))
    }
}
