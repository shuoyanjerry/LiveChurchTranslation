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
        guard !text.isEmpty else { return false }
        let output = compacted(text)
        let terms = promptTerms(in: hotwords)
        guard !output.isEmpty, !terms.isEmpty else { return false }
        if terms.joined() == output { return true }
        for start in terms.indices {
            var candidate = ""
            for end in start..<terms.endIndex {
                candidate += terms[end]
                if end - start + 1 >= 6, candidate == output { return true }
                if candidate.count >= output.count { break }
            }
        }
        return false
    }

    static func promptEchoPrefixTermCount(_ text: String, hotwords: String) -> Int? {
        let output = compacted(text)
        let terms = promptTerms(in: hotwords)
        guard !output.isEmpty, !terms.isEmpty else { return nil }

        let minimumCandidateCount = terms.count <= 5 ? terms.count : 6
        for count in stride(from: terms.count, through: minimumCandidateCount, by: -1) {
            let prefix = terms.prefix(count).joined()
            if output.count > prefix.count, output.hasPrefix(prefix) { return count }
        }
        return nil
    }

    static func promptEchoBodyLength(_ text: String, hotwords: String) -> Int? {
        guard let termCount = promptEchoPrefixTermCount(text, hotwords: hotwords) else {
            return nil
        }
        let prefixLength = promptTerms(in: hotwords).prefix(termCount).joined().count
        return max(0, compacted(text).count - prefixLength)
    }

    static func compactedLength(_ text: String) -> Int {
        compacted(text).count
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

    private static func promptTerms(in text: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",，、;；\n")
        return text.components(separatedBy: separators)
            .map(compacted)
            .filter { !$0.isEmpty }
    }

    private static func compacted(_ text: String) -> String {
        text.unicodeScalars.filter { !tokenSeparators.contains($0) }.map(String.init).joined()
            .lowercased()
    }

}
