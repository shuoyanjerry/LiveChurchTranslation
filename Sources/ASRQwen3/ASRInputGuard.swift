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
        return
            context
            .components(separatedBy: separators)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(limit)
            .joined(separator: ",")
    }
}
