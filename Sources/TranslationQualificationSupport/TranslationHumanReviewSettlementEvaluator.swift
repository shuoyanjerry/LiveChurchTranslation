import Foundation

struct TranslationHumanReviewResolution: Sendable {
    let resolvedCount: Int
    let outstandingCount: Int
    let reviewFailureCount: Int
    let bindingFailureCount: Int
}

enum HumanReviewSettlementEvaluator {
    static func evaluate(
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation?,
        sidecarData: Data?
    ) -> TranslationHumanReviewResolution {
        guard let expectation else {
            return failedBinding(
                outstanding: TranslationHumanReviewOutstanding.count(in: report)
            )
        }
        let requirements: [TranslationHumanReviewRequirement]
        do {
            let binding = try TranslationHumanReviewEvidence.reportBinding(for: report)
            requirements = try TranslationHumanReviewRequirements.derive(
                attempts: expectation.trustedAttempts,
                segments: expectation.corpus.manifest.segments,
                reportBinding: binding
            )
        } catch {
            return failedBinding(outstanding: 0)
        }
        guard let sidecarData,
            let settlement = try? TranslationHumanReviewEvidence.decodeSettlement(from: sidecarData)
        else {
            return failedBinding(outstanding: requirements.count)
        }
        let failures = HumanReviewBindingValidator.failureCount(
            report: report,
            expectation: expectation,
            settlement: settlement,
            requirements: requirements
        )
        guard failures == 0 else {
            return failedBinding(outstanding: requirements.count, failures: failures)
        }
        return HumanReviewResolutionBuilder.resolve(
            requirements,
            submissions: settlement.submissions
        )
    }

    private static func failedBinding(
        outstanding: Int,
        failures: Int = 1
    ) -> TranslationHumanReviewResolution {
        TranslationHumanReviewResolution(
            resolvedCount: 0,
            outstandingCount: outstanding,
            reviewFailureCount: 0,
            bindingFailureCount: max(1, failures)
        )
    }
}
