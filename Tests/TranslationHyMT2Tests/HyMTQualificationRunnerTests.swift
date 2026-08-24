import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMTQualificationRunnerTests {
    @Test func replaysInOrderWithOnlyLastTwoSuccessfulPairsAndNoReferenceInput() async throws {
        let segments = try HyMTQualificationSyntheticFixture.segments()
        let pronounOutput = try HyMTQualificationSyntheticFixture.unresolvedPronounOutput()
        let outputs = segments.map { segment in
            segment.pronounOccurrences.isEmpty ? "Synthetic heading" : pronounOutput
        }
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: outputs.map { .success($0) },
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )
        let attempts = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: traceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: segments)
        let prompts = await harness.transport.completionRequests().map(\.prompt)

        #expect(attempts.map(\.segmentID) == segments.map(\.id))
        #expect(attempts.allSatisfy { $0.status == .success })
        #expect(attempts.allSatisfy { $0.contextSegmentIDs.count <= 2 })
        #expect(
            attempts.dropFirst().allSatisfy { attempt in
                attempt.pronounResults.allSatisfy { $0.englishPolicyStatus == .pass }
            })
        #expect(traceStatus(attempts[0]) == .notApplicable)
        #expect(attempts.dropFirst().allSatisfy { traceStatus($0) == .pass })
        #expect(prompts.count == 4)
        #expect(prompts.allSatisfy { !$0.contains("Reference-only marker") })
        #expect(prompts.dropFirst(2).contains { $0.contains("They remain present.") })
        await harness.provider.shutdown()
    }

    @Test func failedCompletionNeverEntersRollingContext() async throws {
        let segments = try HyMTQualificationSyntheticFixture.segments()
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let pronounOutput = try HyMTQualificationSyntheticFixture.unresolvedPronounOutput()
        let harness = try await makeTranslationHarness(
            responses: [
                .success("Synthetic heading"),
                .failure(.transportFailure("synthetic")),
                .success(pronounOutput),
                .success(pronounOutput),
            ],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )

        let attempts = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: traceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: segments)

        #expect(
            attempts.map(\.contextSegmentIDs) == [
                [], ["synthetic-1"], ["synthetic-1"], ["synthetic-1", "synthetic-3"],
            ])
        #expect(attempts[1].status == .failure)
        await harness.provider.shutdown()
    }

    @Test func validatorApprovedStrictRetryEntersRollingContext() async throws {
        let segments = try HyMTQualificationSyntheticFixture.segments()
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let pronounOutput = try HyMTQualificationSyntheticFixture.unresolvedPronounOutput()
        let harness = try await makeTranslationHarness(
            responses: [
                .success("Synthetic heading"),
                .success(""), .success(pronounOutput),
                .success(pronounOutput), .success(pronounOutput),
            ],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )

        let attempts = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: traceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: segments)

        #expect(
            attempts[1].completionOutcomes == [
                "initial.validationRejected", "strictRetry.accepted",
            ])
        #expect(attempts[2].contextSegmentIDs == ["synthetic-1", "synthetic-2"])
        await harness.provider.shutdown()
    }

    @Test func safeReviewedCompletionIsSuccessButNeverEntersRollingContext() async throws {
        let segments = try HyMTQualificationSyntheticFixture.segments()
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        let pronounOutput = try HyMTQualificationSyntheticFixture.unresolvedPronounOutput()
        let reviewOutput = "The translation is central to communication."
        let harness = try await makeTranslationHarness(
            responses: [
                .success(reviewOutput), .success(reviewOutput),
                .success(pronounOutput), .success(pronounOutput), .success(pronounOutput),
            ],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )

        let attempts = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: traceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: segments)

        #expect(attempts[0].status == .success)
        #expect(attempts[0].failureCode == nil)
        #expect(attempts[0].backendReviewIssueCodes?.contains("quality.meta_text") == true)
        #expect(!TranslationQualificationCompletionPolicy.approvesContext(attempts[0]))
        #expect(attempts[1].contextSegmentIDs.isEmpty)
        await harness.provider.shutdown()
    }

}

extension HyMTQualificationRunnerTests {
    fileprivate func traceStatus(
        _ attempt: TranslationQualificationAttempt
    ) -> TranslationQualificationCheckStatus? {
        attempt.preservationChecks.first {
            $0.kind == "pronounTraceIntegrity"
        }?.status
    }
}
