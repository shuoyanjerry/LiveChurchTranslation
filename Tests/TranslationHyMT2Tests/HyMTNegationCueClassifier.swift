import Foundation
import NaturalLanguage

enum HyMTNegationCueClassifier {
    static func sourceClasses(_ source: String) -> [HyMTNegationSourceCueClass] {
        let specific = ranges(of: specificPhrases, in: source)
        let compounds = ranges(of: compoundBuPhrases, in: source)
        let occupied = specific + compounds
        let standalone = standaloneBuRanges(in: source).filter { range in
            !occupied.contains { $0.overlaps(range) }
        }
        let residualBu = source.indices.contains { index in
            source[index] == "不"
                && !occupied.contains { $0.contains(index) }
                && !standalone.contains { $0.contains(index) }
        }
        let found: Set<HyMTNegationSourceCueClass> = [
            specific.isEmpty ? nil : .specificPhrase,
            compounds.isEmpty ? nil : .compoundBu,
            standalone.isEmpty ? nil : .standaloneBu,
            residualBu ? .embeddedBu : nil,
        ].compactMap { $0 }.reduce(into: []) { $0.insert($1) }
        guard !found.isEmpty else { return [.none] }
        return HyMTNegationSourceCueClass.allCases.filter(found.contains)
    }

    static func targetClass(_ target: String) -> HyMTNegationTargetCueClass {
        let lower = target.lowercased().replacingOccurrences(of: "’", with: "'")
        let words = Set(matches(pattern: #"[a-z]+(?:'[a-z]+)?"#, in: lower))
        if words.contains(where: isExplicit) { return .explicit }
        if lexicalPhrases.contains(where: lower.contains) { return .lexical }
        if !words.isDisjoint(with: lexicalWords) { return .lexical }
        return .none
    }

    private static func isExplicit(_ word: String) -> Bool {
        explicitWords.contains(word) || word.hasSuffix("n't")
    }

    private static func standaloneBuRanges(in source: String) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = source
        tokenizer.setLanguage(.simplifiedChinese)
        var result: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: source.startIndex..<source.endIndex) { range, _ in
            if source[range] == "不" { result.append(range) }
            return true
        }
        return result
    }

    private static func ranges(
        of needles: [String],
        in text: String
    ) -> [Range<String.Index>] {
        needles.flatMap { needle in
            var result: [Range<String.Index>] = []
            var remaining = text.startIndex..<text.endIndex
            while let range = text.range(of: needle, range: remaining) {
                result.append(range)
                remaining = range.upperBound..<text.endIndex
            }
            return result
        }
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }

    private static let specificPhrases = ["没有", "并非", "从未", "未曾"]
    private static let compoundBuPhrases = ["不是", "不可", "不能", "不要", "不得"]
    private static let explicitWords = Set([
        "not", "no", "never", "without", "neither", "nor", "cannot",
    ])
    private static let lexicalPhrases = ["rather than", "instead of", "free from"]
    private static let lexicalWords = Set([
        "absent", "absence", "avoid", "avoided", "avoids", "avoiding",
        "deny", "denied", "denies", "denying", "fail", "failed", "fails",
        "failure", "failing", "forbid", "forbidden", "forbids", "forbidding",
        "impossible", "lack", "lacked", "lacking", "lacks", "reject",
        "rejected", "rejecting", "rejects", "unable",
    ])
}
