import Foundation

enum HyMT2GenderValidator {
    static func issues(
        in target: String,
        source: String
    ) -> [OutputValidationIssue] {
        guard !containsDeityReference(source) else { return [] }
        let hasFemale = containsPronoun("她", in: source)
        let hasMale = containsPronoun(
            "他",
            in: source,
            excluding: ["其他", "他人", "吉他"]
        )
        guard hasFemale != hasMale else { return [] }
        let words = Set(matches(pattern: #"[A-Za-z]+"#, in: target.lowercased()))
        if hasFemale, !words.isDisjoint(with: masculinePronouns) {
            return [.unexpectedMasculinePronoun]
        }
        if hasMale, !words.isDisjoint(with: femininePronouns) {
            return [.unexpectedFemininePronoun]
        }
        return []
    }

    private static let masculinePronouns = Set(["he", "him", "his", "himself"])
    private static let femininePronouns = Set(["she", "her", "hers", "herself"])

    private static func containsPronoun(
        _ pronoun: Character,
        in source: String,
        excluding protectedLexemes: [String] = []
    ) -> Bool {
        let protectedRanges = protectedLexemes.flatMap { ranges(of: $0, in: source) }
        return source.indices.contains { index in
            source[index] == pronoun
                && !protectedRanges.contains(where: { $0.contains(index) })
        }
    }

    private static func ranges(
        of term: String,
        in source: String
    ) -> [Range<String.Index>] {
        guard !term.isEmpty else { return [] }
        var result: [Range<String.Index>] = []
        var searchStart = source.startIndex
        while searchStart < source.endIndex {
            guard
                let range = source.range(
                    of: term,
                    range: searchStart..<source.endIndex
                )
            else { break }
            result.append(range)
            searchStart = range.upperBound
        }
        return result
    }

    private static func containsDeityReference(_ source: String) -> Bool {
        ["神", "上帝", "主", "耶稣", "基督", "圣灵", "祂"].contains(where: source.contains)
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }
}
