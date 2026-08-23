import Foundation

enum HyMT2NegationShadowEnglishNegator {
    static func adjacent(
        before markerStart: String.Index,
        after markerEnd: String.Index,
        in output: String
    ) -> String? {
        if markerEnd < output.endIndex, isWordCharacter(output[markerEnd]) { return nil }
        var start = markerStart
        while start > output.startIndex {
            let previous = output.index(before: start)
            guard isWordCharacter(output[previous]) else { break }
            start = previous
        }
        guard start < markerStart else { return nil }
        let raw = String(output[start..<markerStart]).lowercased()
            .replacingOccurrences(of: "’", with: "'")
        return allowed.contains(raw) ? raw : nil
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        if character == "'" || character == "’" { return true }
        guard character.unicodeScalars.count == 1,
            let scalar = character.unicodeScalars.first
        else { return false }
        return (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    private static let allowed: Set<String> = [
        "not", "no", "never", "cannot", "without", "neither", "nor",
        "aren't", "can't", "couldn't", "didn't", "doesn't", "don't", "hadn't", "hasn't",
        "haven't", "isn't", "mustn't", "needn't", "shan't", "shouldn't", "wasn't", "weren't",
        "won't", "wouldn't",
    ]
}
