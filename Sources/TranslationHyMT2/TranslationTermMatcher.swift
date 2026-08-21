import Foundation
import TranslationAPI

enum TranslationTermMatcher {
    static func matched(
        in source: String,
        from glossary: [TranslationTerm],
        limit: Int
    ) -> [TranslationTerm] {
        var seen = Set<String>()
        let candidates = glossary.compactMap { term -> Candidate? in
            let key = term.source.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !key.isEmpty, !term.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                seen.insert(key).inserted
            else { return nil }
            let matches = ranges(of: term.source, in: source)
            return matches.isEmpty ? nil : Candidate(term: term, ranges: matches)
        }.sorted {
            if $0.term.source.count != $1.term.source.count {
                return $0.term.source.count > $1.term.source.count
            }
            return $0.term.source < $1.term.source
        }

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
}
