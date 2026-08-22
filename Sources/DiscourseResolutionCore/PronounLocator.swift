import DiscourseResolutionAPI

enum PronounLocator {
    private static let connectors = [
        "但是", "可是", "然而", "所以", "然后", "因此", "不过", "而且", "因为", "后来",
    ]
    private static let sentenceEndings: Set<Character> = ["。", "！", "？", "!", "?", "；", ";"]
    private static let separators: Set<Character> = ["，", ",", "、", "：", ":"]

    static func scan(_ text: String) -> PronounScan {
        if containsProtectedLexeme(text) {
            return PronounScan(candidates: [], constraints: [.lexicalOccurrenceProtected])
        }
        let pronouns = text.indices.filter { isPronoun(text[$0]) }
        guard !pronouns.isEmpty else {
            return PronounScan(candidates: [], constraints: [])
        }
        let eligible = candidateIndices(in: text)
        guard let firstPronoun = pronouns.first, eligible.contains(firstPronoun) else {
            return PronounScan(candidates: [], constraints: [.ineligiblePronounPosition])
        }
        return PronounScan(
            candidates: eligible.map { index in
                let next = text.index(after: index)
                return PronounCandidate(range: index..<next, original: String(text[index]))
            },
            constraints: []
        )
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

    private static func containsProtectedLexeme(_ text: String) -> Bool {
        text.contains("他人") || text.contains("其他") || text.contains("吉他")
    }

    private static func isPronoun(_ character: Character) -> Bool {
        character == "他" || character == "她"
    }
}
