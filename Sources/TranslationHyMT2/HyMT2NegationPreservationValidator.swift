import Foundation

enum HyMT2NegationPreservationValidator {
    static func isMissing(
        source: String,
        target: String,
        sourceLanguage: String,
        targetLanguage: String
    ) -> Bool {
        let sourceIsChinese = sourceLanguage.lowercased().hasPrefix("zh")
        let targetIsChinese = targetLanguage.lowercased().hasPrefix("zh")
        guard sourceIsChinese != targetIsChinese else { return false }

        if sourceIsChinese {
            guard let expected = HyMT2ChineseNegationScanner.requiredCueCount(in: source) else {
                return false
            }
            return expected > 0 && HyMT2EnglishNegationScanner.targetCueCount(in: target) < expected
        }

        let expected = HyMT2EnglishNegationScanner.sourceCueCount(in: source)
        return expected > 0 && HyMT2ChineseNegationScanner.targetCueCount(in: target) < expected
    }
}

private enum HyMT2EnglishNegationScanner {
    static func sourceCueCount(in text: String) -> Int {
        cueCount(in: text, includeLexicalRealizations: false)
    }

    static func targetCueCount(in text: String) -> Int {
        cueCount(in: text, includeLexicalRealizations: true)
    }

    private static func cueCount(
        in text: String,
        includeLexicalRealizations: Bool
    ) -> Int {
        let words = englishWords(
            text.lowercased().replacingOccurrences(of: "’", with: "'")
        )
        var count = 0
        var index = 0
        var unmatchedNeither = false
        while index < words.count {
            let word = words[index]
            if isExcludedPair(at: index, in: words) {
                index += 2
                continue
            }
            if isNegativePair(at: index, in: words) {
                count += 1
                index += 2
                continue
            }
            if isWhetherOrNot(at: index, in: words) {
                index += 1
                continue
            }
            if word == "neither" {
                count += 1
                unmatchedNeither = true
            } else if word == "nor", unmatchedNeither {
                unmatchedNeither = false
            } else if directCues.contains(word) || word.hasSuffix("n't") {
                count += 1
            } else if includeLexicalRealizations && lexicalCues.contains(word) {
                count += 1
            }
            index += 1
        }
        return count
    }

    private static func isExcludedPair(at index: Int, in words: [String]) -> Bool {
        pair(["no", "matter"], at: index, in: words)
            || pair(["not", "only"], at: index, in: words)
    }

    private static func isNegativePair(at index: Int, in words: [String]) -> Bool {
        pair(["rather", "than"], at: index, in: words)
            || pair(["instead", "of"], at: index, in: words)
    }

    private static func isWhetherOrNot(at index: Int, in words: [String]) -> Bool {
        index >= 2
            && words[index] == "not"
            && words[index - 1] == "or"
            && words[..<(index - 1)].suffix(4).contains("whether")
    }

    private static func pair(
        _ pair: [String],
        at index: Int,
        in words: [String]
    ) -> Bool {
        words.indices.contains(index + 1)
            && words[index] == pair[0]
            && words[index + 1] == pair[1]
    }

    private static func englishWords(_ value: String) -> [String] {
        guard
            let expression = try? NSRegularExpression(
                pattern: #"[A-Za-z]+(?:'[A-Za-z]+)?"#
            )
        else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }
    }

    private static let directCues: Set<String> = [
        "cannot", "hardly", "neither", "never", "no", "nobody", "none", "nor",
        "not", "nothing", "nowhere", "rarely", "scarcely", "seldom", "without",
    ]

    private static let lexicalCues: Set<String> = [
        "absence", "absent", "avoided", "avoiding", "avoids", "avoid", "denied",
        "denies", "denying", "deny", "excluded", "excludes", "excluding", "exclude",
        "forbade", "forbid", "forbidden", "forbids", "lacked", "lacking", "lacks",
        "lack", "broke", "broken", "immutable", "omitted", "omitting", "omits", "omit",
        "powerless", "prohibited", "prohibiting", "prohibits", "prohibit", "refused",
        "refuses", "refusing", "refuse", "rejected", "rejecting", "rejects", "reject",
        "unable", "unrestricted", "unwilling", "violated", "violates", "violating",
        "violate",
    ]
}
