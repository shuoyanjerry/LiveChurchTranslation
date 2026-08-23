import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2PronounBestEffortProviderTests {
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
}
