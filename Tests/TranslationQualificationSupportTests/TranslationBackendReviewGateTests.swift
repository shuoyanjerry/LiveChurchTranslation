import Testing
import TranslationQualificationSupport

@Suite struct TranslationBackendReviewGateTests {
    @Test func reviewedCompletionIsNotAProviderFailureButBlocksRelease() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let baseline = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let index = baseline.attempts.count - 1
        let segment = corpus.manifest.segments[index]
        let reviewed = SyntheticTranslationAttemptCopy.make(
            baseline.attempts[index],
            segment: segment,
            outcomes: ["initial.validationRejected", "strictRetry.validationRejected"],
            backendReviewIssueCodes: ["quality.missing_negation"]
        )
        var attempts = baseline.attempts
        attempts[index] = reviewed
        let report = try TranslationQualificationReportBuilder.build(
            generatedAt: baseline.generatedAt,
            corpus: corpus,
            provider: baseline.provider,
            environment: baseline.environment,
            attempts: attempts
        )
        let result = TranslationQualificationReleaseGate.evaluate(report)

        #expect(report.aggregate.successCount == 100)
        #expect(report.aggregate.failureCount == 0)
        #expect(result.providerFailureCount == 0)
        #expect(result.backendReviewAttemptCount == 1)
        #expect(result.backendReviewIssueCount == 1)
        #expect(!result.passesReleaseReadyGates)
    }

    @Test func pronounSafetyFallbackIsCountedButCannotBecomeReleaseReady() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let baseline = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let index = baseline.attempts.count - 1
        let reviewed = SyntheticTranslationAttemptCopy.make(
            baseline.attempts[index],
            segment: corpus.manifest.segments[index],
            outcomes: [
                "initial.validationRejected",
                "strictRetry.validationRejected",
                "safetyFallback.accepted",
            ],
            backendReviewIssueCodes: ["quality.pronoun_alignment"]
        )
        var attempts = baseline.attempts
        attempts[index] = reviewed

        let report = try TranslationQualificationReportBuilder.build(
            generatedAt: baseline.generatedAt,
            corpus: corpus,
            provider: baseline.provider,
            environment: baseline.environment,
            attempts: attempts
        )
        let result = TranslationQualificationReleaseGate.evaluate(report)

        #expect(report.aggregate.successCount == 100)
        #expect(report.aggregate.failureCount == 0)
        #expect(report.aggregate.safetyFallbackCount == 1)
        #expect(result.providerFailureCount == 0)
        #expect(result.backendReviewAttemptCount == 1)
        #expect(!result.passesReleaseReadyGates)
        #expect(!TranslationQualificationCompletionPolicy.approvesContext(reviewed))
    }
}
