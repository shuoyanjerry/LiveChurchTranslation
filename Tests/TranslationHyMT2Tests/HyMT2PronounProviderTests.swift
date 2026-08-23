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
        let rejected = "\(anchored(plan, 0, "she")) asked \(anchored(plan, 1, "him"))."
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

    @Test func secondSafeAlignmentFailureIsShownForReviewAndNeverTraced() async throws {
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

        #expect(result.targetText == "he continued.")
        #expect(result.review?.issueCodes == ["quality.pronoun_alignment"])
        #expect(!result.targetText.contains("QLR_"))
        #expect(await trace.observations().isEmpty)
        #expect(await harness.transport.completionRequests().count == 2)
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

    @Test func mixedExactMarkerFormatsAreRemovedAndTranslationIsShown() async throws {
        let source = "她和他继续。"
        let guidance = [
            guidance(0, .verifiedFemale),
            guidance(2, .verifiedMale),
        ]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let mixed =
            "\(anchored(plan, 0, "she")) and \(flatCertified(plan, 1, "him")) continued."
        let harness = try await makeTranslationHarness(responses: [
            .success(mixed), .success(mixed),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [],
                pronounGuidance: guidance
            )
        )

        #expect(result.targetText == "she and him continued.")
        #expect(result.review?.issueCodes == ["quality.pronoun_protocol"])
        #expect(!result.targetText.contains("QLR"))
    }

    @Test func hiddenFidelityIssuesDoNotLetWorsePronounCandidateWin() async throws {
        let source = "她不是靠行为得救。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let initial = "\(anchored(plan, 0, "he")) receives life by works."
        let strict = "\(anchored(plan, 0, "she")) receives salvation by works."
        let harness = try await makeTranslationHarness(responses: [
            .success(initial), .success(strict),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [TranslationTerm(source: "得救", target: "salvation")],
                pronounGuidance: guidance
            )
        )

        #expect(result.targetText == "she receives salvation by works.")
        #expect(result.review?.issueCodes == ["quality.missing_negation"])
    }

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
