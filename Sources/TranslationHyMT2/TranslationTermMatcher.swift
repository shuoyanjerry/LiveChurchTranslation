import Foundation
import TranslationAPI

enum TranslationTermMatcher {
    static func matched(
        in source: String,
        from glossary: [TranslationTerm],
        limit: Int
    ) -> [TranslationTerm] {
        let candidates = candidates(in: source, from: glossary)
        return selectNonoverlapping(candidates, limit: limit)
    }

    private static func candidates(
        in source: String,
        from glossary: [TranslationTerm]
    ) -> [Candidate] {
        var seen = Set<String>()
        return glossary.compactMap {
            candidate(for: $0, in: source, seen: &seen)
        }.sorted {
            if $0.longestMatch != $1.longestMatch {
                return $0.longestMatch > $1.longestMatch
            }
            return $0.term.source < $1.term.source
        }
    }

    private static func candidate(
        for term: TranslationTerm,
        in source: String,
        seen: inout Set<String>
    ) -> Candidate? {
        let key = normalized(term.source)
        guard !key.isEmpty, !term.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            seen.insert(key).inserted
        else { return nil }
        let matchedPhrases = ([term.source] + term.sourceAliases).compactMap { phrase in
            let matches = ranges(of: phrase, in: source)
            return matches.isEmpty ? nil : MatchedPhrase(text: phrase, ranges: matches)
        }
        let matches = matchedPhrases.flatMap(\.ranges)
        let longestMatch = matchedPhrases.map(\.text.count).max() ?? 0
        return matches.isEmpty
            ? nil
            : Candidate(term: term, ranges: matches, longestMatch: longestMatch)
    }

    private static func selectNonoverlapping(
        _ candidates: [Candidate],
        limit: Int
    ) -> [TranslationTerm] {
        var occupied: [Range<String.Index>] = []
        var selected: [TranslationTerm] = []
        for candidate in candidates where selected.count < max(0, limit) {
            let available = candidate.ranges.filter { range in
                !occupied.contains(where: { $0.overlaps(range) })
            }
            guard !available.isEmpty else { continue }
            selected.append(candidate.term)
            occupied.append(contentsOf: available)
        }
        return selected
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func ranges(
        of term: String,
        in source: String
    ) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var searchStart = source.startIndex
        while searchStart < source.endIndex {
            guard
                let match = source.range(
                    of: term,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchStart..<source.endIndex
                )
            else { break }
            result.append(match)
            searchStart = match.upperBound
        }
        return result
    }
}

private struct Candidate {
    let term: TranslationTerm
    let ranges: [Range<String.Index>]
    let longestMatch: Int
}

private struct MatchedPhrase {
    let text: String
    let ranges: [Range<String.Index>]
}
