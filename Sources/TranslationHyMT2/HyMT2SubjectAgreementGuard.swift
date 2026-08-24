enum HyMT2SubjectAgreementGuard {
    static func isNumberInvariant(
        after markerEnd: String.Index,
        in output: String
    ) -> Bool {
        guard let word = immediateASCIIWord(after: markerEnd, in: output) else {
            return false
        }
        let normalized = word.lowercased()
        return normalized.hasSuffix("ed") || invariantAuxiliaries.contains(normalized)
    }

    private static func immediateASCIIWord(
        after markerEnd: String.Index,
        in output: String
    ) -> String? {
        var start = markerEnd
        while start < output.endIndex, output[start].isWhitespace {
            start = output.index(after: start)
        }
        var end = start
        while end < output.endIndex, isASCIIWordLetter(output[end]) {
            end = output.index(after: end)
        }
        guard end > start else { return nil }
        if end < output.endIndex {
            let terminator = output[end]
            guard !terminator.isLetter, !terminator.isNumber else { return nil }
        }
        return String(output[start..<end])
    }

    private static func isASCIIWordLetter(_ character: Character) -> Bool {
        HyMT2PronounTokenBoundary.isASCIILetter(character)
    }

    private static let invariantAuxiliaries = Set([
        "can", "could", "did", "had", "may", "might", "must", "shall", "should", "will",
        "would",
    ])
}
