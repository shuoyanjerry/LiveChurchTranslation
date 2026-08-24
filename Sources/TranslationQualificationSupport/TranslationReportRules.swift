import Foundation

extension TranslationQualificationReportBuilder {
    static func isSHA(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    static func isISO8601(_ value: String) -> Bool {
        if ISO8601DateFormatter().date(from: value) != nil { return true }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) != nil
    }

    static func isFailureCode(_ value: String?) -> Bool {
        guard let value, !value.isEmpty, value.count <= 64 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }

    static let metricPolicy = [
        "All segment failures remain in the denominator.",
        "Human references are review-only and are never prompt or context input.",
        "No BLEU, exact string match, or reference overlap alone determines semantic quality.",
        "Automated checks are preservation and pronoun-policy guards, not adequacy scores.",
        "Safe nonempty provider completions with quality warnings remain successes "
            + "and record backendReviewIssueCodes.",
        "Backend-reviewed completions never enter rolling translation context or pass release-ready gates.",
        "Pronoun safety-fallback completions are always backend-reviewed and never enter context.",
    ]
}
