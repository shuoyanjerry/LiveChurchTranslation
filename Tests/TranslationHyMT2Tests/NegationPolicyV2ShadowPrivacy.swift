import Foundation
@testable import TranslationQualificationSupport

enum NegationPolicyV2ShadowPrivacy {
    static func encoded(
        _ report: NegationPolicyV2ShadowReport,
        sensitiveValues: [String]
    ) throws -> Data {
        try NegationPolicyV2ShadowValidator.validate(report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try validateSerialized(data, sensitiveValues: sensitiveValues)
        return data
    }

    static func validateSerialized(
        _ data: Data,
        sensitiveValues: [String]
    ) throws {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        let object = try JSONSerialization.jsonObject(with: data)
        var strings: [String] = []
        try scan(object, strings: &strings)
        let sensitive = sensitiveValues.map(trimmed).filter { !$0.isEmpty }
        for value in strings {
            guard isSHA(value) else { throw NegationPolicyV2ShadowError.privacyViolation }
            let leaks = sensitive.contains { secret in
                value == secret || (isHighSignal(secret) && value.contains(secret))
            }
            guard !leaks else { throw NegationPolicyV2ShadowError.privacyViolation }
        }
    }

    private static func scan(_ value: Any, strings: inout [String]) throws {
        if let object = value as? [String: Any] {
            for (key, child) in object {
                guard allowedKeys.contains(key) else {
                    throw NegationPolicyV2ShadowError.privacyViolation
                }
                try scan(child, strings: &strings)
            }
        } else if let string = value as? String {
            strings.append(string)
        } else if value is NSNumber {
            return
        } else {
            throw NegationPolicyV2ShadowError.privacyViolation
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isHighSignal(_ value: String) -> Bool {
        value.count >= 8 || value.unicodeScalars.contains(where: { $0.properties.isIdeographic })
    }

    private static func isSHA(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static let allowedKeys = Set([
        "schemaVersion", "manifestSHA256", "classifiedReportSHA256", "policySHA256",
        "configurationSHA256", "totalSegmentCount", "classifiedSuccessCount",
        "classifiedFailureCount", "allSegmentsSource", "successfulAttemptsFull",
        "failedAttemptsSource", "acceptedUnsafeTargetUnicodeCount", "totalCount",
        "dispositions", "overtCueRequirements", "humanReviewReasons",
        "noFunctionalNegation", "requiresOvertCue", "humanReviewRequired", "one", "two",
        "three", "fourOrMore", "mixedPolarityClauses", "questionScope",
        "quantifierScope", "targetCueCountMismatch", "unexpectedTargetCue",
        "unclassifiedSourceCue", "unsafeSourceUnicode", "unsafeTargetUnicode",
    ])
}
