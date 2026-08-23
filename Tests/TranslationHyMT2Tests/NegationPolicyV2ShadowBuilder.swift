import Foundation
import TranslationQualificationSupport

enum NegationPolicyV2ShadowBuilder {
    static func make(
        corpus: TranslationQualificationCorpus,
        classified: HyMTNegationClassifiedEvidence,
        workspaceRoot: URL
    ) throws -> NegationPolicyV2ShadowReport {
        let segments = corpus.manifest.segments
        guard segments.count == classified.attempts.count else {
            throw NegationPolicyV2ShadowError.invalidInput
        }
        let sets = try collect(segments: segments, attempts: classified.attempts)
        let successfulAggregate = try NegationPolicyV2ShadowCounts.aggregate(
            sets.successfulFull
        )
        let report = NegationPolicyV2ShadowReport(
            schemaVersion: 1,
            manifestSHA256: corpus.manifestSHA256,
            classifiedReportSHA256: classified.reportSHA256,
            policySHA256: try NegationPolicyV2ShadowIdentity.policySHA256(
                workspaceRoot: workspaceRoot
            ),
            configurationSHA256: try NegationPolicyV2ShadowIdentity.configurationSHA256(),
            totalSegmentCount: segments.count,
            classifiedSuccessCount: sets.successfulFull.count,
            classifiedFailureCount: sets.failedSource.count,
            allSegmentsSource: try NegationPolicyV2ShadowCounts.aggregate(sets.allSource),
            successfulAttemptsFull: successfulAggregate,
            failedAttemptsSource: try NegationPolicyV2ShadowCounts.aggregate(sets.failedSource),
            acceptedUnsafeTargetUnicodeCount:
                successfulAggregate.humanReviewReasons.unsafeTargetUnicode
        )
        try NegationPolicyV2ShadowValidator.validate(report)
        return report
    }
}
