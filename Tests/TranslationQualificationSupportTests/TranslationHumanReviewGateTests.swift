import Testing
import TranslationQualificationSupport

@Suite struct TranslationHumanReviewGateTests {
    @Test func twoIndependentSignedReviewsResolveDerivedCoverage() throws {
        let values = try releaseValues()
        let itemIDs = try TranslationHumanReviewEvidence.requiredReviewItemIDs(
            report: values.report,
            expectation: values.expectation
        )
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation
        )
        let result = TranslationQualificationReleaseGate.evaluate(
            values.report,
            expectation: values.expectation,
            humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
        )

        #expect(result.humanReviewRequiredCount > 0)
        #expect(itemIDs.allSatisfy { $0.count == 64 })
        #expect(
            itemIDs.count
                == result.humanReviewRequiredCount + result.backendReviewIssueCount + (98 * 5)
        )
        #expect(result.resolvedHumanReviewCount == itemIDs.count)
        #expect(result.outstandingHumanReviewCount == 0)
        #expect(result.reviewFailureCount == 0)
        #expect(result.reviewBindingFailureCount == 0)
        #expect(result.passesReleaseReadyGates)
        try TranslationQualificationReleaseGate.requireReleaseReadyGates(
            values.report,
            expectation: values.expectation,
            humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
        )
    }

    @Test func absenceOfSidecarIsAlwaysNoGoEvenWithNoReviewItems() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let result = TranslationQualificationReleaseGate.evaluate(
            values.report,
            expectation: values.expectation
        )

        #expect(result.humanReviewRequiredCount == 0)
        #expect(result.outstandingHumanReviewCount == 0)
        #expect(result.reviewBindingFailureCount == 1)
        #expect(!result.passesReleaseReadyGates)
    }

    @Test func sidecarKeysMustBeAnchoredOutsideTheSidecar() throws {
        let fixture = try SyntheticTranslationWorkspace(requiresHumanReview: false)
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let expectation = try SyntheticTranslationReportFactory.releaseExpectation(corpus: corpus)
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: report,
            expectation: expectation
        )
        let result = TranslationQualificationReleaseGate.evaluate(
            report,
            expectation: expectation,
            humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
        )

        #expect(expectation.trustedHumanReviewers.isEmpty)
        #expect(result.reviewBindingFailureCount > 0)
        #expect(!result.passesReleaseReadyGates)
    }

    @Test func resolvableBackendWarningRequiresAndAcceptsBothReviews() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let baseline = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let index = baseline.attempts.count - 1
        let reviewed = SyntheticTranslationAttemptCopy.make(
            baseline.attempts[index],
            segment: corpus.manifest.segments[index],
            outcomes: ["initial.validationRejected", "strictRetry.validationRejected"],
            backendReviewIssueCodes: ["quality.implausible_length"]
        )
        let report = try replacing(baseline, corpus: corpus, index: index, with: reviewed)
        let expectation = try SyntheticHumanReviewSettlementFactory.expectation(
            report: report,
            corpus: corpus
        )
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: report,
            expectation: expectation
        )
        let result = TranslationQualificationReleaseGate.evaluate(
            report,
            expectation: expectation,
            humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
        )

        #expect(result.backendReviewIssueCount == 1)
        #expect(result.passesReleaseReadyGates)
    }
}

private func replacing(
    _ baseline: TranslationQualificationReport,
    corpus: TranslationQualificationCorpus,
    index: Int,
    with attempt: TranslationQualificationAttempt
) throws -> TranslationQualificationReport {
    var attempts = baseline.attempts
    attempts[index] = attempt
    return try TranslationQualificationReportBuilder.build(
        generatedAt: baseline.generatedAt,
        corpus: corpus,
        provider: baseline.provider,
        environment: baseline.environment,
        executionProvenance: baseline.executionProvenance,
        attempts: attempts
    )
}
