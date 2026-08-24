import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2SafetyFallbackTests {
    @Test func safeThirdCompletionIsShownForReviewWithoutInternalProtocol() async throws {
        let source = "她继续。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let recorder = HyMTQualificationAttemptRecorder()
        let trace = SafetyFallbackTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source), .success("She continued.")],
            attemptObserver: recorder,
            pronounTraceObserver: trace
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "She continued.")
        #expect(result.review?.issueCodes == ["quality.pronoun_alignment"])
        #expect(await trace.observations().isEmpty)
        verifyPrompts(
            await harness.transport.completionRequests().map(\.prompt),
            plan: plan,
            source: source
        )
        let summary = await recorder.takeSummary(for: pronounTestRequestID)
        #expect(summary.safetyFallbackUsed)
        #expect(summary.completionAttemptCount == 3)
        #expect(
            summary.outcomes == [
                "initial.validationRejected",
                "strictRetry.validationRejected",
                "safetyFallback.accepted",
            ]
        )
    }

    @Test func unsafeThirdCompletionRemainsRetryableWithoutEchoingInput() async throws {
        let source = "她继续。"
        let recorder = HyMTQualificationAttemptRecorder()
        let harness = try await makeTranslationHarness(
            responses: [
                .success(source),
                .success(source),
                .success(HyMT2PromptControlDelimiter.currentSourceClosing),
            ],
            attemptObserver: recorder
        )
        defer { harness.model.remove() }

        let error = await safetyFallbackInvalidOutput(
            from: harness.provider,
            request: safetyFallbackRequest(source)
        )

        #expect(error?.translationFailureImpact == .retryableUtterance)
        #expect(error?.localizedDescription.contains(source) == false)
        #expect(error?.localizedDescription.contains("QLR_") == false)
        let summary = await recorder.takeSummary(for: pronounTestRequestID)
        #expect(
            summary.outcomes == [
                "initial.validationRejected",
                "strictRetry.validationRejected",
                "safetyFallback.validationRejected",
            ]
        )
    }

    @Test func thirdCompletionRejectsBareProtocolIdentifiers() async throws {
        let source = "她继续。"
        for residual in [
            "P0001", "P9999", "P 9 9 9 9", "P0\u{200B}001", "QLR_VERIFIED_FEMALE",
        ] {
            let harness = try await makeTranslationHarness(
                responses: [
                    .success(source),
                    .success(source),
                    .success("She \(residual) continued."),
                ]
            )
            defer { harness.model.remove() }

            let error = await safetyFallbackInvalidOutput(
                from: harness.provider,
                request: safetyFallbackRequest(source)
            )

            #expect(error?.translationFailureImpact == .retryableUtterance)
            #expect(error?.localizedDescription.contains(residual) == false)
            #expect(await harness.transport.completionRequests().count == 3)
            await harness.provider.shutdown()
        }
    }

    private func verifyPrompts(
        _ prompts: [String],
        plan: HyMT2PronounPlan,
        source: String
    ) {
        #expect(prompts.count == 3)
        #expect(prompts[0].contains(plan.protectedSource))
        #expect(prompts[1].contains(plan.protectedSource))
        #expect(prompts[2].contains(source))
        #expect(!prompts[2].contains(plan.protectedSource))
        #expect(!prompts[2].contains(HyMT2PromptControlDelimiter.pronounAlignmentOpening))
        #expect(!prompts[2].contains(HyMT2PromptControlDelimiter.pronounRetryOpening))
        #expect(plan.occurrences.allSatisfy { !prompts[2].contains($0.protectedBlock) })
    }
}

func safetyFallbackRequest(_ source: String) -> TranslationRequest {
    TranslationRequest(
        id: pronounTestRequestID,
        sourceText: source,
        glossary: [],
        pronounGuidance: [guidance(0, .verifiedFemale)]
    )
}

func safetyFallbackInvalidOutput(
    from provider: HyMT2TranslationProvider,
    request: TranslationRequest
) async -> HyMT2Error? {
    do {
        _ = try await provider.translate(request)
        Issue.record("Expected invalid output")
        return nil
    } catch let error as HyMT2Error {
        guard case .invalidOutput = error else {
            Issue.record("Unexpected error: \(error)")
            return nil
        }
        return error
    } catch {
        Issue.record("Unexpected error: \(error)")
        return nil
    }
}

private actor SafetyFallbackTraceRecorder: HyMT2PronounTraceObserving {
    private var values: [HyMT2PronounTraceObservation] = []

    func record(_ observation: HyMT2PronounTraceObservation) {
        values.append(observation)
    }

    func observations() -> [HyMT2PronounTraceObservation] {
        values
    }
}
