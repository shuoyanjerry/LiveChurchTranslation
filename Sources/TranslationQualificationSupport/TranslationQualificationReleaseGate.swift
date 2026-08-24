import Foundation

public struct TranslationQualificationGateResult: Equatable, Sendable {
    public let providerFailureCount: Int
    public let hardCheckFailureCount: Int
    public let releaseCheckFailureCount: Int
    public let humanReviewRequiredCount: Int
    public let backendReviewAttemptCount: Int
    public let backendReviewIssueCount: Int
    public let provenanceBindingFailureCount: Int
    public let resolvedHumanReviewCount: Int
    public let outstandingHumanReviewCount: Int
    public let reviewFailureCount: Int
    public let reviewBindingFailureCount: Int

    public var passesHardGates: Bool {
        providerFailureCount == 0 && hardCheckFailureCount == 0
    }

    public var passesReleaseReadyGates: Bool {
        providerFailureCount == 0
            && releaseCheckFailureCount == 0
            && provenanceBindingFailureCount == 0
            && outstandingHumanReviewCount == 0
            && reviewFailureCount == 0
            && reviewBindingFailureCount == 0
    }
}

public enum TranslationQualificationReleaseGate {
    public static func evaluate(
        _ report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation? = nil,
        humanReviewSidecar: Data? = nil
    ) -> TranslationQualificationGateResult {
        let attempts = report.attempts
        let review = HumanReviewSettlementEvaluator.evaluate(
            report: report,
            expectation: expectation,
            sidecarData: humanReviewSidecar
        )
        return TranslationQualificationGateResult(
            providerFailureCount: attempts.filter { $0.status == .failure }.count,
            hardCheckFailureCount: attempts.reduce(0) { $0 + hardFailures(in: $1) },
            releaseCheckFailureCount: attempts.reduce(0) { $0 + allFailures(in: $1) },
            humanReviewRequiredCount: attempts.reduce(0) { $0 + reviews(in: $1) },
            backendReviewAttemptCount: attempts.filter {
                !($0.backendReviewIssueCodes ?? []).isEmpty
            }.count,
            backendReviewIssueCount: attempts.reduce(0) {
                $0 + ($1.backendReviewIssueCodes ?? []).count
            },
            provenanceBindingFailureCount:
                expectation.map {
                    TranslationProvenanceValidator.isReleaseBound(report, expectation: $0)
                } == true ? 0 : 1,
            resolvedHumanReviewCount: review.resolvedCount,
            outstandingHumanReviewCount: review.outstandingCount,
            reviewFailureCount: review.reviewFailureCount,
            reviewBindingFailureCount: review.bindingFailureCount
        )
    }

    public static func requireReleaseReadyGates(
        _ report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        humanReviewSidecar: Data? = nil
    ) throws {
        let result = evaluate(
            report,
            expectation: expectation,
            humanReviewSidecar: humanReviewSidecar
        )
        guard result.passesReleaseReadyGates else {
            throw TranslationQualificationError.invalidReport(
                "translation qualification release-ready gates failed"
            )
        }
    }

    public static func requireAttestedReleaseReadyGates(
        _ report: TranslationQualificationReport,
        expectation: TranslationAttestedReleaseExpectation,
        humanReviewSidecar: Data
    ) throws {
        try requireReleaseReadyGates(
            report,
            expectation: expectation.releaseExpectation,
            humanReviewSidecar: humanReviewSidecar
        )
    }

    private static func allFailures(in attempt: TranslationQualificationAttempt) -> Int {
        attempt.glossaryTerms.filter { $0.status == .fail }.count
            + attempt.preservationChecks.filter { $0.status == .fail }.count
            + attempt.pronounResults.reduce(0) { count, result in
                count + (result.guidanceStatus == .fail ? 1 : 0)
                    + (result.englishPolicyStatus == .fail ? 1 : 0)
            }
    }

    public static func requireHardGates(
        _ report: TranslationQualificationReport
    ) throws {
        let result = evaluate(report)
        guard result.passesHardGates else {
            throw TranslationQualificationError.invalidReport(
                "translation qualification hard gates failed"
            )
        }
    }

    private static func hardFailures(in attempt: TranslationQualificationAttempt) -> Int {
        let requiredTerms = attempt.glossaryTerms.filter { $0.required && $0.status == .fail }.count
        let preservation = attempt.preservationChecks.filter {
            hardPreservationKinds.contains($0.kind) && $0.status == .fail
        }.count
        let pronouns = attempt.pronounResults.reduce(0) { count, result in
            count + (result.guidanceStatus == .fail ? 1 : 0)
                + (result.englishPolicyStatus == .fail ? 1 : 0)
        }
        return requiredTerms + preservation + pronouns
    }

    private static func reviews(in attempt: TranslationQualificationAttempt) -> Int {
        attempt.preservationChecks.filter { $0.status == .humanReviewRequired }.count
            + attempt.glossaryTerms.filter { $0.status == .humanReviewRequired }.count
            + attempt.pronounResults.reduce(0) { count, result in
                count + (result.guidanceStatus == .humanReviewRequired ? 1 : 0)
                    + (result.englishPolicyStatus == .humanReviewRequired ? 1 : 0)
            }
    }

    private static let hardPreservationKinds = Set([
        "negation", "numbers", "scriptureReference", "pronounTraceIntegrity",
    ])
}
