import Foundation
import TranslationQualificationSupport

enum HyMTNegationReportConsistency {
    static func validate(_ entry: HyMTNegationDiagnosticEntry) throws {
        let sourceOrder = ordered(entry.sourceCueClasses, all: HyMTNegationSourceCueClass.allCases)
        try require(sourceOrder == entry.sourceCueClasses, "source cue classes are not canonical")
        try require(!sourceOrder.contains(.none), "selected source lacks a negation cue")
        try require(
            entry.classifiedFailureCode.split(separator: ".").contains("neg"),
            "classified failure is not a negation failure"
        )
        let expectedOrdinals = Array(1...max(1, entry.attemptCount)).prefix(entry.attemptCount)
        try require(
            entry.attempts.map(\.ordinal) == Array(expectedOrdinals),
            "attempt ordinals are not contiguous"
        )
        for attempt in entry.attempts { try validate(attempt) }
        let completionLatency = entry.attempts.reduce(0) { $0 + $1.latencySeconds }
        try require(
            entry.totalLatencySeconds + tolerance >= completionLatency,
            "completion latency exceeds total latency"
        )
        try validateTerminal(entry)
    }

    private static func validate(_ attempt: HyMTNegationDiagnosticAttempt) throws {
        let issueOrder = ordered(
            attempt.validationIssueCodes,
            all: HyMTNegationDiagnosticIssueCode.allCases
        )
        try require(issueOrder == attempt.validationIssueCodes, "validation issues are not canonical")
        if attempt.completionOutcome.hasSuffix(".accepted") {
            try require(
                attempt.outputAvailable && attempt.validationIssueCodes.isEmpty,
                "accepted completion has validation issues"
            )
        } else if attempt.completionOutcome.hasSuffix(".validationRejected") {
            try require(
                attempt.outputAvailable && !attempt.validationIssueCodes.isEmpty,
                "validation rejection lacks diagnostic issues"
            )
        } else {
            try require(
                !attempt.outputAvailable && attempt.validationIssueCodes == [.transportFailure],
                "transport failure contains an output"
            )
        }
    }

    private static func validateTerminal(_ entry: HyMTNegationDiagnosticEntry) throws {
        let accepted = entry.attempts.last?.completionOutcome.hasSuffix(".accepted") == true
        if entry.terminalFailureCode == "none" {
            try require(accepted, "successful diagnostic lacks an accepted completion")
        } else {
            try require(!accepted, "failed diagnostic ends in an accepted completion")
        }
    }

    private static func ordered<Value: Hashable>(
        _ values: [Value],
        all: [Value]
    ) -> [Value] {
        let unique = Set(values)
        return all.filter(unique.contains)
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }

    private static let tolerance = 0.000_001
}
