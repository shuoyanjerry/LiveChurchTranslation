import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2BestEffortRefusalTests {
    @Test func wrapperCannotExposeARefusalOrSourceLabel() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("Translation: I cannot translate this request."),
            .success("Here is the translation: Source text: private prompt"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: [])
    }

    @Test func commonRefusalTextIsNotPresentedAsTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("Sorry, I’m unable to translate this request."),
            .success("I can't help translate this request."),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: [])
    }

    @Test func politeEnglishRefusalIsNotPresentedAsTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("“I'm sorry, but I can't translate this request.”"),
            .success("Sorry, but I cannot translate that request."),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: [])
    }

    @Test func politeChineseRefusalIsNotPresentedAsTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("很抱歉，我无法翻译这个请求。"),
            .success("对不起，我不能帮助翻译此内容。"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: [],
            request: TranslationRequest(
                sourceText: "Please continue with the sermon.",
                sourceLanguage: "en",
                targetLanguage: "zh-Hans",
                glossary: []
            )
        )
    }

    @Test func aSpokenRefusalStillReceivesItsFaithfulTranslation() async throws {
        let expected = "I cannot translate this request."
        let harness = try await makeTranslationHarness(responses: [
            .success(expected), .success(expected),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(sourceText: "我不能翻译这个请求。", glossary: [])
        )

        #expect(result.targetText == expected)
        #expect(result.review != nil)
    }

    @Test(arguments: [
        "I  cannot translate this request.",
        "I can\u{200B}not translate this request.",
        "Ａｓ ａｎ ＡＩ, I cannot translate this request.",
    ])
    func disguisedRefusalTextIsNotPresentedAsTranslation(_ refusal: String) async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success(refusal), .success("Translation: \(refusal)"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: [])
    }
}
