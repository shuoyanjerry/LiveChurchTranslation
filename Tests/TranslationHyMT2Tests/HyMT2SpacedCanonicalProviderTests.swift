import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2SpacedCanonicalProviderTests {
    @Test func bindingOnlyInitialFailureEnablesSpacedStrictRetry() async throws {
        let fixture = try makeSpacedProviderFixture()
        let strict = spacedCanonical(fixture.plan, 0, "She") + "continued."
        let trace = SpacedCanonicalTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(fixture.initial), .success(strict)],
            pronounTraceObserver: trace
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(fixture.request)

        #expect(result.targetText == "She continued.")
        #expect(!result.targetText.contains("QLR"))
        #expect(await trace.values().map(\.phase) == [.strictRetry])
    }

    @Test func acceptsExactPublicDeityHumanTerminalShapeAndTracesBoth() async throws {
        let source = "弟兄感谢神，因为他安慰了他。"
        let guidance = [
            guidance(8, .verifiedDeity),
            guidance(12, .verifiedMale),
        ]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let output =
            "Brother thanks God, because \(spacedCanonical(plan, 0, "He"))comforted "
            + "him \(plan.occurrences[1].protectedBlock)."
        let trace = SpacedCanonicalTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(output), .success(output)],
            pronounTraceObserver: trace
        )
        defer { harness.model.remove() }
        let request = TranslationRequest(
            id: pronounTestRequestID,
            sourceText: source,
            glossary: [],
            pronounGuidance: guidance
        )

        let result = try await harness.provider.translate(request)
        let observations = await trace.values()

        #expect(result.targetText == "Brother thanks God, because He comforted him.")
        #expect(!result.targetText.contains("QLR"))
        #expect(observations.count == 2)
        #expect(observations.allSatisfy { $0.phase == .strictRetry })
        #expect(observations.map(\.sourceRange) == guidance.map(\.sourceRange))
        #expect(observations.map(\.resolution) == [.verifiedDeity, .verifiedMale])
        #expect(observations.map(\.realizationClass) == [.masculine, .masculine])
    }
}

@MainActor
@Suite struct HyMT2SpacedCanonicalRejectionTests {
    @Test func strictExactNonceBlockDoesNotNeedFlatCapability() async throws {
        let fixture = try makeSpacedProviderFixture()
        let strict = spacedCanonical(fixture.plan, 0, "She") + "continued."
        let trace = SpacedCanonicalTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success("He continued."), .success(strict)],
            pronounTraceObserver: trace
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(fixture.request)

        #expect(result.targetText == "She continued.")
        #expect(await trace.values().map(\.phase) == [.strictRetry])
    }

    @Test func wrongSpacedPronounIsShownWithoutProtocolForBackendReview() async throws {
        let fixture = try makeSpacedProviderFixture()
        let strict = spacedCanonical(fixture.plan, 0, "He") + "continued."
        let harness = try await makeTranslationHarness(
            responses: [.success(fixture.initial), .success(strict)]
        )

        defer { harness.model.remove() }
        let result = try await harness.provider.translate(fixture.request)

        #expect(result.targetText == "He continued.")
        #expect(result.review?.issueCodes == ["quality.pronoun_alignment"])
        #expect(!result.targetText.contains("QLR"))
        #expect(await harness.transport.completionRequests().count == 2)
    }
}

private struct SpacedProviderFixture {
    let plan: HyMT2PronounPlan
    let initial: String
    let request: TranslationRequest
}

private func makeSpacedProviderFixture() throws -> SpacedProviderFixture {
    let source = "她继续。"
    let guidance = [guidance(0, .verifiedFemale)]
    let plan = try makePronounPlan(source: source, guidance: guidance)
    return SpacedProviderFixture(
        plan: plan,
        initial: "\(anchored(plan, 0, "he")) continued.",
        request: TranslationRequest(
            id: pronounTestRequestID,
            sourceText: source,
            glossary: [],
            pronounGuidance: guidance
        )
    )
}

private actor SpacedCanonicalTraceRecorder: HyMT2PronounTraceObserving {
    private var recorded: [HyMT2PronounTraceObservation] = []

    func record(_ observation: HyMT2PronounTraceObservation) {
        recorded.append(observation)
    }

    func values() -> [HyMT2PronounTraceObservation] {
        recorded
    }
}
