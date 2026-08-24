import Foundation

extension TranslationPreservationEvaluator {
    static func reviewCheck(
        kind: String,
        applicable: Bool,
        hypothesis: String?
    ) -> TranslationQualificationCheck {
        guard applicable else { return check(kind, .notApplicable) }
        return check(kind, hypothesis == nil ? .fail : .humanReviewRequired)
    }

    static func check(
        _ kind: String,
        _ status: TranslationQualificationCheckStatus,
        expected: [String] = [],
        observed: [String] = []
    ) -> TranslationQualificationCheck {
        TranslationQualificationCheck(
            kind: kind,
            status: status,
            expected: expected,
            observed: observed
        )
    }

    static func englishWords(_ text: String) -> [String] {
        matches(#"[A-Za-z]+(?:'[A-Za-z]+)?"#, in: text.lowercased())
    }

    static func negationCheck(
        source: String,
        hypothesis: String?
    ) -> TranslationQualificationCheck {
        let sourceCueCount = chineseNegationCueCount(in: source)
        let expected = [sourceNegationFact(sourceCueCount)]
        guard let hypothesis else {
            return check(
                "negation",
                sourceCueCount == 0 ? .notApplicable : .fail,
                expected: expected,
                observed: [missingTargetFact]
            )
        }
        let targetCueCount = englishNegationCueCount(in: hypothesis)
        let observed = [targetNegationFact(targetCueCount)]
        guard sourceCueCount > 0 else {
            return check(
                "negation",
                .notApplicable,
                expected: expected,
                observed: observed
            )
        }
        return check(
            "negation",
            targetCueCount > 0 ? .pass : .humanReviewRequired,
            expected: expected,
            observed: observed
        )
    }

    static func chineseNegationCueCount(in text: String) -> Int {
        let characters = Array(text)
        let cues = chineseNegations.sorted {
            $0.count == $1.count ? $0 < $1 : $0.count > $1.count
        }.map(Array.init)
        var count = 0
        var index = 0
        while index < characters.count {
            guard let cue = cues.first(where: { characters[index...].starts(with: $0) }) else {
                index += 1
                continue
            }
            count += 1
            index += cue.count
        }
        return count
    }

    static func englishNegationCueCount(in text: String) -> Int {
        englishWords(text).filter {
            englishNegations.contains($0) || $0.hasSuffix("n't")
        }.count
    }

    static func sourceNegationFact(_ count: Int) -> String {
        "machine.source_surface_negation_cue_count=\(count)"
    }

    static func targetNegationFact(_ count: Int) -> String {
        "machine.target_overt_negation_cue_count=\(count)"
    }

    static func matches(_ pattern: String, in text: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return expression.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    static let chineseNegations = [
        "没有", "并非", "不是", "不可", "不能", "不要", "不得", "从未", "未曾", "不",
    ]
    static let englishNegations = Set([
        "not", "no", "never", "without", "neither", "nor", "cannot",
    ])
    static let missingTargetFact = "machine.target_availability=missing"
}
