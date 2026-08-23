import DiscourseResolutionAPI

enum PronounLocator {
    private static let connectors = [
        "但是", "可是", "然而", "所以", "然后", "因此", "不过", "而且", "因为", "后来",
    ]
    private static let sentenceEndings: Set<Character> = ["。", "！", "？", "!", "?", "；", ";"]
    private static let separators: Set<Character> = ["，", ",", "、", "：", ":"]
    private static let protectedLexemes = [
        "他们", "她们", "它们", "祂们", "他們", "她們", "它們", "祂們",
        "他俩", "她俩", "它俩", "祂俩", "他人", "其他", "其它", "吉他",
    ]

    static func scan(_ text: String) -> PronounScan {
        let protectedRanges = protectedLexemes.flatMap { ranges(of: $0, in: text) }
        let pronouns = text.indices.filter { index in
            isPronoun(text[index])
                && !protectedRanges.contains(where: { $0.contains(index) })
        }
        let observed = candidates(at: pronouns, in: text)
        var constraints: [DiscourseResolutionConstraint] = []
        if !protectedRanges.isEmpty { constraints.append(.lexicalOccurrenceProtected) }
        guard let firstPronoun = pronouns.first else {
            return PronounScan(observed: [], eligible: [], constraints: constraints)
        }
        let eligibleIndices = candidateIndices(in: text)
        guard eligibleIndices.contains(firstPronoun) else {
            constraints.append(.ineligiblePronounPosition)
            return PronounScan(observed: observed, eligible: [], constraints: constraints)
        }
        let eligible = pronouns.filter(eligibleIndices.contains)
        return PronounScan(
            observed: observed,
            eligible: candidates(at: eligible, in: text),
            constraints: constraints
        )
    }

    private static func candidates(
        at indices: [String.Index],
        in text: String
    ) -> [PronounCandidate] {
        indices.map { index in
            let next = text.index(after: index)
            return PronounCandidate(range: index..<next, original: String(text[index]))
        }
    }

    private static func candidateIndices(in text: String) -> [String.Index] {
        boundaries(in: text).compactMap { boundary in
            let index = skipSeparators(from: boundary, in: text)
            return index < text.endIndex && isPronoun(text[index]) ? index : nil
        }
    }

    private static func boundaries(in text: String) -> [String.Index] {
        var values = [text.startIndex]
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(after: index)
            if sentenceEndings.contains(text[index]) || text[index].isNewline {
                values.append(next)
            }
            for connector in connectors where text[index...].hasPrefix(connector) {
                values.append(text.index(index, offsetBy: connector.count))
            }
            index = next
        }
        return uniqueSorted(values)
    }

    private static func uniqueSorted(_ values: [String.Index]) -> [String.Index] {
        var result: [String.Index] = []
        for value in values.sorted() where result.last != value {
            result.append(value)
        }
        return result
    }

    private static func skipSeparators(from start: String.Index, in text: String) -> String.Index {
        var index = start
        while index < text.endIndex {
            let character = text[index]
            guard character.isWhitespace || separators.contains(character) else { break }
            index = text.index(after: index)
        }
        return index
    }

    private static func ranges(
        of term: String,
        in text: String
    ) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex {
            guard text[start...].hasPrefix(term) else {
                start = text.index(after: start)
                continue
            }
            let end = text.index(start, offsetBy: term.count)
            ranges.append(start..<end)
            start = end
        }
        return ranges
    }

    private static func isPronoun(_ character: Character) -> Bool {
        character == "他" || character == "她" || character == "祂"
    }
}
