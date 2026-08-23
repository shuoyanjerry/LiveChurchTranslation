import Foundation

enum TranslationComputedEvidenceValidator {
    static func validate(
        attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) throws -> TranslationQualificationCheckStatus {
        let terms = try termExpectations(attempt.glossaryTerms, segment: segment)
        let recomputed = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: attempt.hypothesisEnglish,
            terms: terms
        )
        try require(
            attempt.glossaryTerms == recomputed.terms,
            "glossary result is not reproducible"
        )
        let trace = try traceCheck(
            attempt.preservationChecks,
            expectedChecks: recomputed.checks,
            hypothesisAvailable: attempt.hypothesisEnglish != nil
        )
        return trace.status
    }

    private static func termExpectations(
        _ results: [TranslationQualificationTermResult],
        segment: TranslationQualificationSegment
    ) throws -> [TranslationQualificationTermExpectation] {
        let sources = results.map(\.source)
        try require(Set(sources).count == sources.count, "duplicate glossary result")
        try require(
            results.allSatisfy(validTerm),
            "glossary result has invalid structure"
        )
        try require(
            results.allSatisfy {
                segment.observedASRAmbiguousChinese.localizedStandardContains($0.source)
            },
            "glossary result is not applicable to source"
        )
        let reported = Set(sources)
        try require(
            segment.theologyTerms.allSatisfy(reported.contains),
            "manifest theology term is missing from glossary results"
        )
        return results.map {
            TranslationQualificationTermExpectation(
                source: $0.source,
                preferredTarget: $0.preferredTarget,
                acceptedTargets: $0.acceptedTargets,
                required: $0.required
            )
        }
    }

    private static func validTerm(_ result: TranslationQualificationTermResult) -> Bool {
        let targets = [result.preferredTarget] + result.acceptedTargets
        return !result.source.isEmpty
            && !result.preferredTarget.isEmpty
            && targets.allSatisfy { !$0.isEmpty }
            && Set(targets.map { $0.lowercased() }).count == targets.count
    }

    private static func traceCheck(
        _ checks: [TranslationQualificationCheck],
        expectedChecks: [TranslationQualificationCheck],
        hypothesisAvailable: Bool
    ) throws -> TranslationQualificationCheck {
        try require(
            checks.count == expectedChecks.count + 1,
            "preservation or trace check count mismatch"
        )
        try require(
            Array(checks.prefix(expectedChecks.count)) == expectedChecks,
            "preservation check is not reproducible"
        )
        let trace = checks[expectedChecks.count]
        try require(trace.kind == "pronounTraceIntegrity", "trace integrity check is missing")
        try require(
            trace.expected.isEmpty && trace.observed.isEmpty,
            "trace integrity check contains untrusted detail"
        )
        let allowed: Set<TranslationQualificationCheckStatus> =
            hypothesisAvailable ? [.pass, .fail] : [.notApplicable, .fail]
        try require(allowed.contains(trace.status), "trace integrity status is invalid")
        return trace
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }
}
