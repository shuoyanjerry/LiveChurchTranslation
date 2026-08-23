enum HyMT2PronounTokenBoundary {
    static func hasComplete(
        _ range: Range<String.Index>?,
        in output: String
    ) -> Bool {
        guard let range else { return false }
        guard range.lowerBound > output.startIndex else { return true }
        let previous = output[output.index(before: range.lowerBound)]
        return asciiWhitespace.contains(previous) || allowedLeftDelimiters.contains(previous)
    }

    static func hasAllowedRight(
        after index: String.Index,
        in output: String
    ) -> Bool {
        guard index < output.endIndex else { return true }
        let next = output[index]
        return asciiWhitespace.contains(next) || allowedRightDelimiters.contains(next)
    }

    static func isASCIILetter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
            let scalar = character.unicodeScalars.first
        else { return false }
        return (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    private static let allowedLeftDelimiters = Set<Character>([
        "(", "[", "{", "\"", "“", "”", "«", "»", ",", ".", ";", ":", "!", "?", "…",
    ])
    private static let allowedRightDelimiters = Set<Character>([
        ")", "]", "}", "\"", "”", "»", ",", ".", ";", ":", "!", "?", "…", "，", "。", "；", "：", "！", "？",
    ])
    private static let asciiWhitespace = Set<Character>([" ", "\t", "\n", "\r", "\r\n"])
}
