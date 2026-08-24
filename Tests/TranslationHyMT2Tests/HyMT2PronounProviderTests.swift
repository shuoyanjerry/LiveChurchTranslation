import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2PronounProviderTests {
    @Test func strictRetryReusesIDsAndOnlyAcceptedAttemptEmitsTrace() async throws {
        let source = "她问他。"
        let guidance = [
            guidance(0, .verifiedFemale),
            guidance(2, .unresolvedSpokenMandarin),
        ]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let rejected =
            "\(anchored(plan, 0, "she")) asked \(anchored(plan, 1, "private secret"))."
        let accepted = "\(anchored(plan, 0, "she")) asked \(anchored(plan, 1, "them"))."
        let trace = PronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(rejected), .success(accepted)],
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

        #expect(result.targetText == "she asked them.")
        #expect(!result.targetText.contains("QLR_"))
        let prompts = await harness.transport.completionRequests().map(\.prompt)
        assertStrictPrompt(prompts, plan: plan)
        let observations = await trace.observations()
        #expect(observations.count == 2)
        #expect(observations.allSatisfy { $0.phase == .strictRetry })
        #expect(observations.map(\.sourceRange) == guidance.map(\.sourceRange))
        #expect(observations.map(\.realizationClass) == [.feminine, .singularThey])
    }

    @Test func safeGenderMismatchIsRepairedAndTracedWithoutModelRetry() async throws {
        let source = "她继续。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let wrong = "\(anchored(plan, 0, "he")) continued."
        let trace = PronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(wrong), .success(wrong)],
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

        #expect(result.targetText == "she continued.")
        #expect(result.review == nil)
        #expect(!result.targetText.contains("QLR_"))
        let observations = await trace.observations()
        #expect(observations.map(\.phase) == [.initial])
        #expect(observations.map(\.realizationClass) == [.feminine])
        #expect(await harness.transport.completionRequests().count == 1)
    }

    @Test func selectedReviewedFidelityOutputRetainsValidPronounTrace() async throws {
        let source = "她领受恩典。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let first = "\(anchored(plan, 0, "she")) received kindness."
        let second = "\(anchored(plan, 0, "she")) received a blessing."
        let trace = PronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(first), .success(second)],
            pronounTraceObserver: trace
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [TranslationTerm(source: "恩典", target: "grace")],
                pronounGuidance: guidance
            )
        )

        #expect(result.targetText == "she received a blessing.")
        #expect(result.review?.issueCodes == ["quality.missing_required_term"])
        let observations = await trace.observations()
        #expect(observations.count == 1)
        #expect(observations.first?.phase == .strictRetry)
        #expect(observations.first?.realizationClass == .feminine)
    }

    @Test func invalidRangeFailsBeforeTransport() async throws {
        let harness = try await makeTranslationHarness(responses: [.success("unused")])
        defer { harness.model.remove() }
        let request = TranslationRequest(
            id: pronounTestRequestID,
            sourceText: "他继续。",
            glossary: [],
            pronounGuidance: [guidance(-1, .verifiedMale)]
        )

        await expectInvalidOutput(harness.provider, request: request)

        #expect(await harness.transport.completionRequests().isEmpty)
    }
}

extension HyMT2PronounProviderTests {
    private func assertStrictPrompt(_ prompts: [String], plan: HyMT2PronounPlan) {
        #expect(prompts.count == 2)
        #expect(prompts.allSatisfy { $0.contains(plan.protectedSource) })
        #expect(!prompts[0].contains("PRONOUN_BINDING_OR_POLICY"))
        #expect(prompts[1].contains("PRONOUN_BINDING_OR_POLICY"))
        for occurrence in plan.occurrences {
            #expect(prompts[1].components(separatedBy: occurrence.protectedBlock).count == 2)
        }
    }

    private func expectInvalidOutput(
        _ provider: HyMT2TranslationProvider,
        request: TranslationRequest
    ) async {
        do {
            _ = try await provider.translate(request)
            Issue.record("Expected invalid output")
        } catch let error as HyMT2Error {
            guard case .invalidOutput = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private actor PronounTraceRecorder: HyMT2PronounTraceObserving {
    private var recorded: [HyMT2PronounTraceObservation] = []

    func record(_ observation: HyMT2PronounTraceObservation) {
        recorded.append(observation)
    }

    func observations() -> [HyMT2PronounTraceObservation] {
        recorded
    }
}
