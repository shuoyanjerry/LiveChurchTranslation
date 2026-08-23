import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2BestEffortProviderTests {
    @Test func choosesCandidateWithFewerBackendWarningsWithoutThirdAttempt() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We are made right."),
            .success("Here is the translation: We are made right."),
            .success("This response must never be consumed."),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(requiredTermRequest())

        #expect(result.targetText == "We are made right.")
        #expect(result.review?.issueCodes == ["quality.missing_required_term"])
        #expect(await harness.transport.completionRequests().count == 2)
    }

    @Test func strictUnsafeOutputFallsBackToFirstSafeTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We are made right."),
            .success("<CURRENT_SOURCE>private prompt text</CURRENT_SOURCE>"),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(requiredTermRequest())

        #expect(result.targetText == "We are made right.")
        #expect(result.review?.issueCodes == ["quality.missing_required_term"])
        #expect(!result.targetText.contains("CURRENT_SOURCE"))
    }

    @Test func strictRuntimeFailureFallsBackToFirstSafeTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We are made right."),
            .failure(.transportFailure("connection reset")),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(requiredTermRequest())

        #expect(result.targetText == "We are made right.")
        #expect(result.review?.issueCodes == ["quality.missing_required_term"])
        #expect(await harness.transport.completionRequests().count == 2)
    }

    @Test func legitimateTranslationPhraseIsNeverTruncated() async throws {
        let expected = "The translation is central to communication."
        let harness = try await makeTranslationHarness(responses: [
            .success(expected), .success(expected),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(sourceText: "翻译是沟通的核心。", glossary: [])
        )

        #expect(result.targetText == expected)
        #expect(result.review?.issueCodes.contains("quality.meta_text") == true)
    }

    private func requiredTermRequest() -> TranslationRequest {
        TranslationRequest(
            sourceText: "我们因信称义。",
            glossary: [
                TranslationTerm(source: "因信称义", target: "justification by faith")
            ]
        )
    }

}
