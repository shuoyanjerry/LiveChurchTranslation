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
}
