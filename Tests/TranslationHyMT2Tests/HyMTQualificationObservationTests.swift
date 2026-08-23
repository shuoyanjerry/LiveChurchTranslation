import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMTQualificationObservationTests {
    @Test func recordsStrictRetryWithoutText() async throws {
        let recorder = HyMTQualificationAttemptRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(""), .success("Grace is sufficient.")],
            attemptObserver: recorder
        )
        let request = TranslationRequest(sourceText: "恩典够用。", glossary: [])
        _ = try await harness.provider.translate(request)

        let summary = await recorder.takeSummary(for: request.id)
        #expect(summary.completionAttemptCount == 2)
        #expect(summary.strictRetryUsed)
        #expect(summary.outcomes == ["initial.validationRejected", "strictRetry.accepted"])

        let consumed = await recorder.takeSummary(for: request.id)
        #expect(consumed.completionAttemptCount == 0)
        #expect(!consumed.strictRetryUsed)
        #expect(consumed.outcomes.isEmpty)
    }
}
