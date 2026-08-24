import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounAlternativeListTests {
    @Test(arguments: [
        "He/them/their/theirs/themself/themselves continued.",
        "she ／ her ／ hers later spoke.",
        "they|them|their continued.",
        "HE｜HIM｜HIS continued.",
        "he\u{200B}/him/his continued.",
        "they∕them∕their continued.",
    ])
    func detectsThreeOrMorePronounOptions(_ output: String) {
        #expect(HyMT2PronounAlternativeListDetector.containsAlternativeList(in: output))
    }

    @Test(arguments: [
        "Use he/she when quoting the original note.",
        "They continued sharing the testimony.",
        "The note says she or he may answer.",
    ])
    func preservesOrdinaryProseAndTwoFormQuotes(_ output: String) {
        #expect(!HyMT2PronounAlternativeListDetector.containsAlternativeList(in: output))
    }
}

@MainActor
@Suite struct HyMT2PronounAlternativeListProviderTests {
    @Test func repeatedAlternativeListsReachCleanSafetyFallback() async throws {
        let source = "他后来继续分享这个见证。"
        let guidance = [guidance(0, .unresolvedSpokenMandarin)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let listedPronouns = "He/them/their/theirs/themself/themselves"
        let alternatives =
            "\(anchored(plan, 0, listedPronouns)) "
            + "later continued sharing this testimony."
        let harness = try await makeTranslationHarness(responses: [
            .success(alternatives),
            .success(alternatives),
            .success("They later continued sharing this testimony."),
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

        #expect(result.targetText == "They later continued sharing this testimony.")
        #expect(result.review?.issueCodes == ["quality.pronoun_alignment"])
        let prompts = await harness.transport.completionRequests().map(\.prompt)
        #expect(prompts.count == 3)
        #expect(prompts[1].contains("Never print a slash- or pipe-separated list"))
    }

    @Test func alternativeListIsNeverPresentedWhenAllAttemptsRepeatIt() async throws {
        let source = "他后来继续分享这个见证。"
        let guidance = [guidance(0, .unresolvedSpokenMandarin)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let listedPronouns = "He/them/their/theirs/themself/themselves"
        let marked =
            "\(anchored(plan, 0, listedPronouns)) "
            + "later continued sharing this testimony."
        let unmarked = "He/them/their later continued sharing this testimony."
        let harness = try await makeTranslationHarness(responses: [
            .success(marked), .success(marked), .success(unmarked),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: [marked, unmarked],
            request: TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [],
                pronounGuidance: guidance
            ),
            expectedRequestCount: 3
        )
    }

    @Test func alternativeListStillGetsCleanFallbackAlongsideFidelityIssues() async throws {
        let source = "他后来继续分享3个见证。"
        let guidance = [guidance(0, .unresolvedSpokenMandarin)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let listedPronouns = "He/them/their/theirs/themself/themselves"
        let marked = "\(anchored(plan, 0, listedPronouns)) later continued sharing testimony."
        let harness = try await makeTranslationHarness(responses: [
            .success(marked),
            .success(marked),
            .success("They later continued sharing 3 testimonies."),
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

        #expect(result.targetText == "They later continued sharing 3 testimonies.")
        #expect(result.review?.issueCodes == ["quality.pronoun_alignment"])
        #expect(await harness.transport.completionRequests().count == 3)
    }
}
