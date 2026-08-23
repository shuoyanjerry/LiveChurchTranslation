import Testing
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMTQualificationTraceTests {
    @Test func missingAcceptedTraceNeverPassesPronounPolicy() async throws {
        let segment = try HyMTQualificationSyntheticFixture.segments()[1]
        let recorder = HyMTQualificationAttemptRecorder()
        let disconnectedTraceRecorder = HyMTQualificationPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(try HyMTQualificationSyntheticFixture.unresolvedPronounOutput())],
            attemptObserver: recorder
        )

        let attempt = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: disconnectedTraceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: [segment])[0]

        #expect(attempt.pronounResults.first?.englishPolicyStatus == .fail)
        #expect(traceStatus(attempt) == .fail)
        await harness.provider.shutdown()
    }

    @Test func duplicateAcceptedTraceFailsIntegrity() async throws {
        let segment = try HyMTQualificationSyntheticFixture.segments()[1]
        let recorder = HyMTQualificationAttemptRecorder()
        let traceRecorder = HyMTQualificationPronounTraceRecorder()
        await traceRecorder.record(
            HyMT2PronounTraceObservation(
                requestID: pronounTestRequestID,
                phase: .initial,
                sourceRange: TranslationSourceRange(location: 0, length: 1),
                resolution: .unresolvedSpokenMandarin,
                realizationClass: .singularThey
            )
        )
        let harness = try await makeTranslationHarness(
            responses: [.success(try HyMTQualificationSyntheticFixture.unresolvedPronounOutput())],
            attemptObserver: recorder,
            pronounTraceObserver: traceRecorder
        )

        let attempt = try await HyMTQualificationRunner(
            provider: harness.provider,
            recorder: recorder,
            pronounTraceRecorder: traceRecorder,
            requestIDFactory: { pronounTestRequestID }
        ).run(segments: [segment])[0]

        #expect(traceStatus(attempt) == .fail)
        await harness.provider.shutdown()
    }

    private func traceStatus(
        _ attempt: TranslationQualificationAttempt
    ) -> TranslationQualificationCheckStatus? {
        attempt.preservationChecks.first { $0.kind == "pronounTraceIntegrity" }?.status
    }
}
