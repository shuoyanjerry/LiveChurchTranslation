import Testing
import TranslationQualificationSupport

@Suite struct TranslationHumanReviewSafetyTests {
    @Test func failedOrDisagreeingVerdictsCannotSettleReview() throws {
        let values = try releaseValues()
        let passing = try SyntheticHumanReviewSettlementFactory.reviews(
            report: values.report,
            expectation: values.expectation
        )
        let failed = try replacingLastVerdict(passing, with: .fail)
        let variants = try [
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                firstReviews: failed,
                secondReviews: failed
            ),
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                firstReviews: failed,
                secondReviews: passing
            ),
        ]

        for settlement in variants {
            let result = TranslationQualificationReleaseGate.evaluate(
                values.report,
                expectation: values.expectation,
                humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
            )
            #expect(result.reviewBindingFailureCount == 0)
            #expect(result.reviewFailureCount == 1)
            #expect(result.resolvedHumanReviewCount == passing.count - 1)
            #expect(!result.passesReleaseReadyGates)
        }
    }

    @Test func providerFailureCannotBeOverriddenByHumanReview() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(
            corpus: corpus,
            failingIndex: corpus.manifest.segments.count - 1
        )
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

        #expect(result.providerFailureCount == 1)
        #expect(result.reviewBindingFailureCount == 0)
        #expect(!result.passesReleaseReadyGates)
    }

    @Test func releaseCheckFailureCannotBeOverriddenByHumanReview() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let baseline = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let index = baseline.attempts.count - 1
        let failedTerm = TranslationQualificationTermResult(
            source: "这里",
            preferredTarget: "synthetic term",
            acceptedTargets: [],
            required: false,
            status: .fail
        )
        let changed = SyntheticTranslationAttemptCopy.make(
            baseline.attempts[index],
            segment: corpus.manifest.segments[index],
            glossaryTerms: [failedTerm]
        )
        let report = try rebuild(baseline, corpus: corpus, index: index, attempt: changed)
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

        #expect(result.releaseCheckFailureCount == 1)
        #expect(result.reviewBindingFailureCount == 0)
        #expect(!result.passesReleaseReadyGates)
    }

    @Test func protocolEchoRefusalAndUnknownWarningsAreNeverHumanResolvable() throws {
        let codes = [
            "quality.pronoun_protocol", "quality.meta_text", "quality.source_echo",
            "quality.refusal", "quality.unexpected_script", "quality.validation_failed",
            "quality.unknown_warning",
        ]
        for code in codes {
            let values = try reviewedBackendValues(code: code)
            let settlement = try SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation
            )
            let result = TranslationQualificationReleaseGate.evaluate(
                values.report,
                expectation: values.expectation,
                humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
            )

            #expect(result.backendReviewIssueCount == 1)
            #expect(result.reviewBindingFailureCount == 0)
            #expect(result.reviewFailureCount == 1)
            #expect(!result.passesReleaseReadyGates)
        }
    }
}

private func replacingLastVerdict(
    _ reviews: [TranslationHumanReviewItem],
    with verdict: TranslationHumanReviewVerdict
) throws -> [TranslationHumanReviewItem] {
    var changed = reviews
    let last = try #require(changed.last)
    changed[changed.count - 1] = TranslationHumanReviewItem(
        itemID: last.itemID,
        verdict: verdict
    )
    return changed
}

private func rebuild(
    _ baseline: TranslationQualificationReport,
    corpus: TranslationQualificationCorpus,
    index: Int,
    attempt: TranslationQualificationAttempt
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

private func reviewedBackendValues(
    code: String
) throws -> (report: TranslationQualificationReport, expectation: TranslationReleaseExpectation) {
    let fixture = try SyntheticTranslationWorkspace()
    let corpus = try fixture.load()
    let baseline = try SyntheticTranslationReportFactory.build(corpus: corpus)
    let index = baseline.attempts.count - 1
    let reviewed = SyntheticTranslationAttemptCopy.make(
        baseline.attempts[index],
        segment: corpus.manifest.segments[index],
        outcomes: ["initial.validationRejected", "strictRetry.validationRejected"],
        backendReviewIssueCodes: [code]
    )
    let report = try rebuild(baseline, corpus: corpus, index: index, attempt: reviewed)
    return (
        report,
        try SyntheticHumanReviewSettlementFactory.expectation(report: report, corpus: corpus)
    )
}
