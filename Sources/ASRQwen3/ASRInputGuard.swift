import Foundation

enum ASRInputGuard {
    static func containsSpeech(_ samples: [Float], minimumRMS: Float) -> Bool {
        guard !samples.isEmpty else { return false }
        let energy = samples.reduce(0.0) { partial, sample in
            partial + Double(sample * sample)
        }
        return Float((energy / Double(samples.count)).squareRoot()) >= minimumRMS
    }

    static func hotwords(from context: String, limit: Int) -> String {
        guard limit > 0 else { return "" }
        let separators = CharacterSet(charactersIn: ",，、;；\n")
        var seen = Set<String>()
        var selected: [String] = []
        selected.reserveCapacity(limit)
        for component in context.components(separatedBy: separators) {
            let word = component.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, seen.insert(word).inserted else { continue }
            selected.append(word)
            if selected.count == limit { break }
        }
        return selected.joined(separator: ",")
    }

    static func isPromptOnlyHallucination(_ text: String, hotwords: String) -> Bool {
        !text.isEmpty && removingPromptEchoPrefix(text, hotwords: hotwords).isEmpty
    }

    static func removingPromptEchoPrefix(_ text: String, hotwords: String) -> String {
        let expected = tokens(in: hotwords)
        guard expected.count >= 6 else { return text }
        let compactOutput = compacted(text)
        for count in stride(from: expected.count, through: 6, by: -1) {
            let prefix = expected.prefix(count).joined()
            guard compactOutput.hasPrefix(prefix) else { continue }
            let remainder = suffix(afterCompactedPrefixOfLength: prefix.count, in: text)
            return removingPromptEchoPrefix(remainder, hotwords: hotwords)
        }
        return text
    }

    static func isKnownNonspeechHallucination(_ text: String) -> Bool {
        let normalized = tokens(in: text).joined().lowercased()
        return normalized == "system" || normalized == "系统"
    }

    private static func tokens(in text: String) -> [String] {
        let separators = tokenSeparators
        return text.components(separatedBy: separators).filter { !$0.isEmpty }
    }

    private static let tokenSeparators = CharacterSet.whitespacesAndNewlines.union(
        CharacterSet(charactersIn: ",，、;；。.!！？?：:")
    )

    private static func compacted(_ text: String) -> String {
        text.unicodeScalars.filter { !tokenSeparators.contains($0) }.map(String.init).joined()
    }

    private static func suffix(
        afterCompactedPrefixOfLength target: Int,
        in text: String
    ) -> String {
        var consumed = 0
        var index = text.startIndex
        while index < text.endIndex, consumed < target {
            let next = text.index(after: index)
            if text[index].unicodeScalars.contains(where: { !tokenSeparators.contains($0) }) {
                consumed += 1
            }
            index = next
        }
        let remainder = text[index...]
        let firstContent = remainder.firstIndex { character in
            character.unicodeScalars.contains { !tokenSeparators.contains($0) }
        }
        guard let firstContent else { return "" }
        return String(remainder[firstContent...])
    }
}
