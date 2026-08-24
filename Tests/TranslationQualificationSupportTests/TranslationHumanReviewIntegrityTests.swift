import Testing
import TranslationQualificationSupport

@Suite struct TranslationHumanReviewIntegrityTests {
    @Test func trustedReviewerRegistryRejectsNonCanonicalOrDuplicatePrincipals() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let reviewers = values.expectation.trustedHumanReviewers
        let first = try #require(reviewers.first)
        let second = try #require(reviewers.last)
        let nonCanonical = TranslationHumanReviewerIdentity(
            reviewerID: first.reviewerID,
            reviewerRole: first.reviewerRole,
            qualificationDeclarationSHA256: String(repeating: "ａ", count: 64),
            independenceDeclarationSHA256: first.independenceDeclarationSHA256,
            publicKeyBase64: first.publicKeyBase64
        )

        for invalid in [[first], [first, first], [nonCanonical, second]] {
            #expect(throws: TranslationQualificationError.self) {
                try expectation(values, reviewers: invalid)
            }
        }
    }

    @Test func signaturePolicyAndEveryReportBindingHashDriftFailClosed() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let binding = try TranslationHumanReviewEvidence.reportBinding(for: values.report)
        let wrongBindings = [
            copy(binding, report: zeros),
            copy(binding, manifest: zeros),
            copy(binding, attempts: zeros),
        ]
        var variants = try wrongBindings.map {
            try SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                binding: $0
            )
        }
        variants.append(
            try SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                policyRevision: "unknown-review-policy"
            )
        )
        let valid = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        variants.append(try corruptFirstSignature(valid))

        for settlement in variants {
            let result = try evaluateHumanReview(values, settlement)
            #expect(result.reviewBindingFailureCount > 0)
            #expect(!result.passesReleaseReadyGates)
        }
    }

    @Test func sidecarRequiresExactlyTwoSubmissions() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let valid = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let variants = [
            copy(valid, submissions: Array(valid.submissions.prefix(1))),
            copy(
                valid,
                submissions: valid.submissions + [valid.submissions[0]]
            ),
        ]

        for settlement in variants {
            #expect(try evaluateHumanReview(values, settlement).reviewBindingFailureCount > 0)
        }
    }
}

private func expectation(
    _ values: TranslationReleaseValues,
    reviewers: [TranslationHumanReviewerIdentity]
) throws -> TranslationReleaseExpectation {
    try TranslationReleaseExpectation(
        trustedExecutionProvenance: values.expectation.executionProvenance,
        corpus: values.expectation.corpus,
        provider: values.expectation.provider,
        environment: values.expectation.environment,
        attempts: values.report.attempts,
        trustedHumanReviewers: reviewers,
        trustedHumanReviewPacketSHA256: values.expectation.trustedHumanReviewPacketSHA256,
        trustedHumanReviewerRegistrySHA256:
            values.expectation.trustedHumanReviewerRegistrySHA256
    )
}
