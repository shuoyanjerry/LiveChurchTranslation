import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2BestEffortEchoSafetyTests {
    @Test func unchangedSentenceIsNotPresentedAsACompletedTranslation() async throws {
        let source = "Grace is sufficient for us today."
        let harness = try await makeTranslationHarness(responses: [
            .success(source), .success(source),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: [],
            request: TranslationRequest(
                sourceText: source,
                sourceLanguage: "en",
                targetLanguage: "zh-Hans",
                glossary: []
            )
        )
    }

    @Test func unchangedShortMandarinSentenceIsNotPresentedAsTranslation() async throws {
        let source = "恩典够用。"
        let harness = try await makeTranslationHarness(responses: [
            .success(source), .success(source),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: [],
            request: TranslationRequest(sourceText: source, glossary: [])
        )
    }

    @Test func unchangedShortEnglishSentenceIsNotPresentedAsTranslation() async throws {
        let source = "Amen."
        let harness = try await makeTranslationHarness(responses: [
            .success(source), .success(source),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: [],
            request: TranslationRequest(
                sourceText: source,
                sourceLanguage: "en",
                targetLanguage: "zh-Hans",
                glossary: []
            )
        )
    }

    @Test func chineseWrapperCannotExposeSourceEchoAsTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("译文：原文：内部原文"),
            .success("原文：内部原文"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: ["内部原文"])
    }
}
