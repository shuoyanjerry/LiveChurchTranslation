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
}
