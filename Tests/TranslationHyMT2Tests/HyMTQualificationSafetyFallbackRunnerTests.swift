import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMTSafetyFallbackRunnerTests {
    @Test func reportedAsReviewedSuccessWithoutContextApproval() async throws {
        let segment = try HyMTQualificationSyntheticFixture.segments()[1]
        let source = segment.observedASRAmbiguousChinese
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [
                .success(source),
                .success(source),
                .success("They remain present."),
            ],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )

        let attempt = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: traceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: [segment])[0]

        #expect(attempt.status == .success)
        #expect(attempt.safetyFallbackUsed == true)
        #expect(attempt.completionAttemptCount == 3)
        #expect(attempt.backendReviewIssueCodes == ["quality.pronoun_alignment"])
        #expect(!TranslationQualificationCompletionPolicy.approvesContext(attempt))
        try TranslationQualificationCompletionPolicy.validate(attempt)
        await harness.provider.shutdown()
    }

    @Test func cancellationEscapesInsteadOfBecomingFailureEvidence() async throws {
        let segment = try HyMTQualificationSyntheticFixture.segments()[0]
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [],
            cancellationRequestIndices: [0],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )

        do {
            _ = try await HyMTQualificationRunner(
                provider: harness.provider,
                recorder: recorder,
                pronounTraceRecorder: traceRecorder,
                requestIDFactory: { pronounTestRequestID }
            ).run(segments: [segment])
            Issue.record("Expected cancellation")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        let summary = await recorder.takeSummary(for: pronounTestRequestID)
        #expect(summary.outcomes == ["initial.cancelled"])
        await harness.provider.shutdown()
    }
}
