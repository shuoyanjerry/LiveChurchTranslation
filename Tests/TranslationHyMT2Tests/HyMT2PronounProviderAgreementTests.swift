import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2PronounProviderAgreementTests {
    @Test func unresolvedPastSubjectIsRepairedAndTracedWithoutModelRetry() async throws {
        let source = "他后来继续分享这个见证。"
        let guidance = [guidance(0, .unresolvedSpokenMandarin)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let wrong = "\(anchored(plan, 0, "He")) continued sharing this testimony."
        let trace = AgreementPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(wrong)],
            pronounTraceObserver: trace
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [],
                pronounGuidance: guidance
            )
        )

        #expect(result.targetText == "They continued sharing this testimony.")
        #expect(result.review == nil)
        #expect(await trace.observations().map(\.realizationClass) == [.singularThey])
        #expect(await harness.transport.completionRequests().count == 1)
    }
}

private actor AgreementPronounTraceRecorder: HyMT2PronounTraceObserving {
    private var recorded: [HyMT2PronounTraceObservation] = []

    func record(_ observation: HyMT2PronounTraceObservation) {
        recorded.append(observation)
    }

    func observations() -> [HyMT2PronounTraceObservation] {
        recorded
    }
}
