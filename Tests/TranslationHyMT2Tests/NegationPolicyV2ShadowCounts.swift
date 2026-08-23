enum NegationPolicyV2ShadowCounts {
    static func aggregate(
        _ dispositions: [NegationPolicyV2Disposition]
    ) throws -> NegationPolicyV2ShadowAggregate {
        var counts = NegationPolicyV2ShadowDispositionCounts()
        var overt = NegationPolicyV2ShadowOvertCueCounts()
        var review = NegationPolicyV2ShadowReviewReasonCounts()
        for disposition in dispositions {
            switch disposition {
            case .noFunctionalNegation:
                counts.noFunctionalNegation += 1
            case .requiresOvertCue(let count):
                counts.requiresOvertCue += 1
                try recordOvertCueCount(count, into: &overt)
            case .humanReviewRequired(let reason):
                counts.humanReviewRequired += 1
                recordReviewReason(reason, into: &review)
            }
        }
        return NegationPolicyV2ShadowAggregate(
            totalCount: dispositions.count,
            dispositions: counts,
            overtCueRequirements: overt,
            humanReviewReasons: review
        )
    }

    private static func recordOvertCueCount(
        _ count: Int,
        into result: inout NegationPolicyV2ShadowOvertCueCounts
    ) throws {
        switch count {
        case 1: result.one += 1
        case 2: result.two += 1
        case 3: result.three += 1
        case 4...: result.fourOrMore += 1
        default: throw NegationPolicyV2ShadowError.invalidReport
        }
    }

    private static func recordReviewReason(
        _ reason: NegationPolicyV2ReviewReason,
        into result: inout NegationPolicyV2ShadowReviewReasonCounts
    ) {
        switch reason {
        case .mixedPolarityClauses: result.mixedPolarityClauses += 1
        case .questionScope: result.questionScope += 1
        case .quantifierScope: result.quantifierScope += 1
        case .targetCueCountMismatch: result.targetCueCountMismatch += 1
        case .unexpectedTargetCue: result.unexpectedTargetCue += 1
        case .unclassifiedSourceCue: result.unclassifiedSourceCue += 1
        case .unsafeSourceUnicode: result.unsafeSourceUnicode += 1
        case .unsafeTargetUnicode: result.unsafeTargetUnicode += 1
        }
    }
}
