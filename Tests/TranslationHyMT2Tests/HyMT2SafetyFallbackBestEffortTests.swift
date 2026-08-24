import Testing
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2SafetyFallbackBestEffortTests {
    @Test func qualityImperfectThirdCompletionIsStillShownForBackendReview() async throws {
        let source = "她没有忘记3个人。"
        let harness = try await makeTranslationHarness(
            responses: [
                .success(source),
                .success(source),
                .success("She forgot 3 people."),
            ]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "She forgot 3 people.")
        #expect(
            result.review?.issueCodes
                == ["quality.missing_negation", "quality.pronoun_alignment"]
        )
        #expect(await harness.transport.completionRequests().count == 3)
    }

    @Test func missingSourceNumberIsShownForReviewWithoutEchoingTheNumber() async throws {
        let source = "她在4111111111111111天后继续。"
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source), .success("She continued.")]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "She continued.")
        #expect(!result.targetText.contains("4111111111111111"))
        #expect(
            result.review?.issueCodes
                == ["quality.missing_number", "quality.pronoun_alignment"]
        )
    }

    @Test func backendReviewCodesRemainUniqueAndSorted() async throws {
        let source = "她忠信。"
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source), .success("神 is faithful.")]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "神 is faithful.")
        #expect(
            result.review?.issueCodes
                == ["quality.pronoun_alignment", "quality.unexpected_script"]
        )
    }
}
