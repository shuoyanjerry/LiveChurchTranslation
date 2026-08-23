import Foundation
@testable import TranslationQualificationSupport

enum HyMTNegationDiagnosticPrivacyGuard {
    static func encoded(
        _ report: HyMTNegationDiagnosticReport,
        sensitiveTexts: [String]
    ) throws -> Data {
        try validateReport(report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try validateSerialized(data, sensitiveTexts: sensitiveTexts)
        return data
    }

    static func validateSerialized(
        _ data: Data,
        sensitiveTexts: [String]
    ) throws {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        let object = try JSONSerialization.jsonObject(with: data)
        try HyMTNegationDiagnosticLeakScanner.validate(
            object,
            sensitiveTexts: sensitiveTexts
        )
    }

    private static func validateReport(_ report: HyMTNegationDiagnosticReport) throws {
        try require(report.schemaVersion == 1, "diagnostic schema version is invalid")
        try require(isSHA(report.manifestSHA256), "diagnostic manifest hash is invalid")
        try require(isSHA(report.classifiedReportSHA256), "classified report hash is invalid")
        try require(isSHA(report.modelSHA256), "diagnostic model hash is invalid")
        try require(isISO8601(report.generatedAt), "diagnostic timestamp is invalid")
        try require(!report.entries.isEmpty, "diagnostic report is empty")
        try require(
            Set(report.entries.map(\.segmentID)).count == report.entries.count,
            "diagnostic segment IDs are duplicated"
        )
        for entry in report.entries { try validateEntry(entry) }
    }

    private static func validateEntry(_ entry: HyMTNegationDiagnosticEntry) throws {
        try require(isIdentifier(entry.segmentID), "diagnostic segment ID is unsafe")
        try require(isIdentifier(entry.sourceID), "diagnostic source ID is unsafe")
        try require(entry.sequence > 0, "diagnostic sequence is invalid")
        try require(isCode(entry.classifiedFailureCode), "classified failure code is unsafe")
        try require(isCode(entry.terminalFailureCode), "terminal failure code is unsafe")
        try require(entry.attemptCount == entry.attempts.count, "attempt count is inconsistent")
        try require((0...2).contains(entry.attemptCount), "attempt count is outside provider policy")
        try require(validLatency(entry.totalLatencySeconds), "total latency is invalid")
        for attempt in entry.attempts { try validateAttempt(attempt) }
        try HyMTNegationReportConsistency.validate(entry)
    }

    private static func validateAttempt(_ attempt: HyMTNegationDiagnosticAttempt) throws {
        try require((1...2).contains(attempt.ordinal), "attempt ordinal is invalid")
        let expected: HyMTNegationDiagnosticAttemptPhase =
            attempt.ordinal == 1 ? .initial : .strictRetry
        try require(attempt.phase == expected, "attempt phase is inconsistent")
        try require(validOutcome(attempt.completionOutcome), "completion outcome is unsafe")
        try require(validLatency(attempt.latencySeconds), "attempt latency is invalid")
        try require(isSHA(attempt.outputSHA256), "attempt output hash is invalid")
        if !attempt.outputAvailable {
            try require(
                attempt.validationIssueCodes == [.transportFailure],
                "missing output lacks a transport issue"
            )
        }
    }

    private static func isIdentifier(_ value: String) -> Bool {
        guard (1...128).contains(value.count), value.first?.isLetter == true else { return false }
        return value.unicodeScalars.allSatisfy(identifierCharacters.contains)
    }

    private static func isCode(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64
            && value.unicodeScalars.allSatisfy(codeCharacters.contains)
    }

    private static func isSHA(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func validLatency(_ value: Double) -> Bool {
        value.isFinite && value >= 0
    }

    private static func validOutcome(_ value: String) -> Bool {
        allowedOutcomes.contains(value)
    }

    private static func isISO8601(_ value: String) -> Bool {
        ISO8601DateFormatter().date(from: value) != nil
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }

    private static let identifierCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    )
    private static let codeCharacters = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-"
    )
    private static let allowedOutcomes = Set([
        "initial.accepted", "initial.validationRejected", "initial.transportFailed",
        "strictRetry.accepted", "strictRetry.validationRejected", "strictRetry.transportFailed",
    ])
}
