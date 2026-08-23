import Foundation

enum NegationPolicyV2English {
    static func overtCueCount(in target: String) -> Int {
        let words = englishWords(
            target.lowercased().replacingOccurrences(of: "’", with: "'")
        )
        var count = 0
        var unmatchedNeither = false
        for index in words.indices {
            let word = words[index]
            if isNonFunctionalCue(at: index, words: words) { continue }
            if word == "neither" {
                count += 1
                unmatchedNeither = true
            } else if word == "nor", unmatchedNeither {
                unmatchedNeither = false
            } else if directCues.contains(word) || word.hasSuffix("n't") {
                count += 1
            }
        }
        return count
    }

    private static func isNonFunctionalCue(
        at index: Int,
        words: [String]
    ) -> Bool {
        let isNoMatter =
            words[index] == "no"
            && words.indices.contains(index + 1)
            && words[index + 1] == "matter"
        if isNoMatter {
            return true
        }
        guard words[index] == "not" else { return false }
        if words.indices.contains(index + 1), words[index + 1] == "only" {
            return true
        }
        guard index >= 2, words[index - 1] == "or" else { return false }
        return words[..<(index - 1)].suffix(4).contains("whether")
    }

    private static func englishWords(_ value: String) -> [String] {
        guard
            let expression = try? NSRegularExpression(
                pattern: #"[A-Za-z]+(?:'[A-Za-z]+)?"#
            )
        else {
            return []
        }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }
    }

    private static let directCues: Set<String> = [
        "cannot", "never", "no", "nor", "not", "without",
    ]
}
