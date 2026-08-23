enum NegationPolicyV2ShadowValidator {
    static func validate(_ report: NegationPolicyV2ShadowReport) throws {
        guard
            report.schemaVersion == 1,
            report.manifestSHA256 == HyMTQualificationConfiguration.manifestSHA256,
            report.classifiedReportSHA256
                == NegationPolicyV2ShadowIdentity.classifiedReportSHA256,
            isSHA(report.policySHA256),
            isSHA(report.configurationSHA256),
            report.totalSegmentCount == 144,
            report.classifiedSuccessCount == 109,
            report.classifiedFailureCount == 35,
            report.classifiedSuccessCount + report.classifiedFailureCount
                == report.totalSegmentCount,
            report.allSegmentsSource.totalCount == report.totalSegmentCount,
            report.successfulAttemptsFull.totalCount == report.classifiedSuccessCount,
            report.failedAttemptsSource.totalCount == report.classifiedFailureCount,
            report.acceptedUnsafeTargetUnicodeCount
                == report.successfulAttemptsFull.humanReviewReasons.unsafeTargetUnicode
        else { throw NegationPolicyV2ShadowError.invalidReport }
        try validate(report.allSegmentsSource)
        try validate(report.successfulAttemptsFull)
        try validate(report.failedAttemptsSource)
    }

    private static func validate(
        _ aggregate: NegationPolicyV2ShadowAggregate
    ) throws {
        guard
            aggregate.totalCount >= 0,
            aggregate.dispositions.total == aggregate.totalCount,
            aggregate.overtCueRequirements.total
                == aggregate.dispositions.requiresOvertCue,
            aggregate.humanReviewReasons.total
                == aggregate.dispositions.humanReviewRequired,
            nonnegative(aggregate.dispositions),
            nonnegative(aggregate.overtCueRequirements),
            nonnegative(aggregate.humanReviewReasons)
        else { throw NegationPolicyV2ShadowError.invalidReport }
    }

    private static func isSHA(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func nonnegative(
        _ counts: NegationPolicyV2ShadowDispositionCounts
    ) -> Bool {
        [counts.noFunctionalNegation, counts.requiresOvertCue, counts.humanReviewRequired]
            .allSatisfy { $0 >= 0 }
    }

    private static func nonnegative(
        _ counts: NegationPolicyV2ShadowOvertCueCounts
    ) -> Bool {
        [counts.one, counts.two, counts.three, counts.fourOrMore]
            .allSatisfy { $0 >= 0 }
    }

    private static func nonnegative(
        _ counts: NegationPolicyV2ShadowReviewReasonCounts
    ) -> Bool {
        [
            counts.mixedPolarityClauses, counts.questionScope, counts.quantifierScope,
            counts.targetCueCountMismatch, counts.unexpectedTargetCue,
            counts.unclassifiedSourceCue, counts.unsafeSourceUnicode,
            counts.unsafeTargetUnicode,
        ].allSatisfy { $0 >= 0 }
    }
}
