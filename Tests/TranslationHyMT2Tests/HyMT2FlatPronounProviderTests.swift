import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2FlatPronounProviderTests {
    @Test func bindingOnlyCanonicalFailureEnablesFlatStrictRetry() async throws {
        let source = "她继续。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let initial = "\(anchored(plan, 0, "he")) continued."
        let strict = "\(flatCertified(plan, 0, "She")) continued."
        let trace = FlatPronounTraceRecorder()
        let harness = try await makeTranslationHarness(
            responses: [.success(initial), .success(strict)],
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

        #expect(result.targetText == "She continued.")
        #expect(!result.targetText.contains("QLR_"))
        #expect(await trace.values().map(\.phase) == [.strictRetry])
    }
}

@MainActor
@Suite struct HyMT2FlatPronounAuthorizationTests {
    @Test func structuralInitialFailuresCannotEnableFlatStrictRetry() async throws {
        let source = "她继续。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let wrong = "\(anchored(plan, 0, "he")) continued."
        let occurrence = plan.occurrences[0]
        let female = HyMT2PronounResolutionToken.value(for: .verifiedFemale)
        let male = HyMT2PronounResolutionToken.value(for: .verifiedMale)
        let structuralFailures = [
            "He continued.",
            "he\(String(occurrence.protectedBlock.dropLast())) continued.",
            wrong + " " + wrong,
            wrong.replacingOccurrences(of: female, with: male),
            wrong.replacingOccurrences(of: "P0001", with: "P9999"),
            wrong + " P9999",
        ]
        let strict = "\(flatCertified(plan, 0, "She")) continued."

        for initial in structuralFailures {
            let harness = try await makeTranslationHarness(
                responses: [.success(initial), .success(strict)]
            )
            await expectReviewed(
                harness,
                request: TranslationRequest(
                    id: pronounTestRequestID,
                    sourceText: source,
                    glossary: [],
                    pronounGuidance: guidance
                )
            )
        }
    }

    @Test func nonPronounInitialFailureCannotEnableFlatStrictRetry() async throws {
        let source = "恩典，她继续。"
        let guidance = [guidance(3, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let initial = "\(anchored(plan, 0, "she")) continued."
        let strict = "By grace, \(flatCertified(plan, 0, "she")) continued."
        let harness = try await makeTranslationHarness(
            responses: [.success(initial), .success(strict)]
        )
        let term = TranslationTerm(source: "恩典", target: "grace")

        await expectReviewed(
            harness,
            request: TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [term],
                pronounGuidance: guidance
            )
        )
    }

    @Test func latentFidelityFailureAlsoDeniesBindingCapability() async throws {
        let source = "恩典，她继续。"
        let guidance = [guidance(3, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let initial = "\(anchored(plan, 0, "he")) continued."
        let strict = "By grace, \(flatCertified(plan, 0, "she")) continued."
        let harness = try await makeTranslationHarness(
            responses: [.success(initial), .success(strict)]
        )

        await expectReviewed(
            harness,
            request: TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [TranslationTerm(source: "恩典", target: "grace")],
                pronounGuidance: guidance
            )
        )
    }

    @Test func replayedCanonicalNonceCannotUnlockCurrentFlatRetry() async throws {
        let source = "她继续。"
        let guidance = [guidance(0, .verifiedFemale)]
        let currentPlan = try makePronounPlan(source: source, guidance: guidance)
        let replayID = try #require(
            UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")
        )
        let replayedPlan = try #require(
            try HyMT2PronounPlan.make(
                source: source,
                guidance: guidance,
                requestID: replayID
            )
        )
        let initial = "\(anchored(replayedPlan, 0, "he")) continued."
        let strict = "\(flatCertified(currentPlan, 0, "She")) continued."
        let harness = try await makeTranslationHarness(
            responses: [.success(initial), .success(strict)]
        )

        await expectReviewed(
            harness,
            request: TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [],
                pronounGuidance: guidance
            )
        )
    }
}

@MainActor
private func expectReviewed(
    _ harness: TranslationHarness,
    request: TranslationRequest
) async {
    defer { harness.model.remove() }
    let result = try? await harness.provider.translate(request)
    #expect(result != nil)
    #expect(result?.review != nil)
    #expect(result?.targetText.contains("QLR") == false)
    #expect(await harness.transport.completionRequests().count == 2)
}

private actor FlatPronounTraceRecorder: HyMT2PronounTraceObserving {
    private var recorded: [HyMT2PronounTraceObservation] = []

    func record(_ observation: HyMT2PronounTraceObservation) {
        recorded.append(observation)
    }

    func values() -> [HyMT2PronounTraceObservation] {
        recorded
    }
}
