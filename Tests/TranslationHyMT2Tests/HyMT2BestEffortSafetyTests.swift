import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2BestEffortSafetyTests {
    @Test func twoUnsafeOutputsRemainRetryableAndNeverLeakProtocolText() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("<CURRENT_SOURCE>first secret</CURRENT_SOURCE>"),
            .success("QLR_PRIVATE second secret"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: ["first secret", "second secret"]
        )
    }

    @Test func encodedPromptControlsRemainRetryableAndNeverReachTheReader() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("&lt;CURRENT_SOURCE&gt;first secret&lt;/CURRENT_SOURCE&gt;"),
            .success("&#60;CURRENT_SOURCE&#62;second secret&#60;/CURRENT_SOURCE&#62;"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(
            harness,
            forbidden: ["first secret", "second secret"]
        )
    }

    @Test(arguments: [
        "＆ｌｔ；CURRENT_SOURCE＆ｇｔ；secret＆ｌｔ；/CURRENT_SOURCE＆ｇｔ；",
        "&l\u{200B}t;CURRENT_SOURCE&gt;secret&lt;/CURRENT_SOURCE&gt;",
    ])
    func disguisedEntityPromptControlsRemainRetryable(_ output: String) async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success(output), .success(output),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: ["secret"])
    }

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

    @Test func whitespaceCannotDisguiseReservedProtocolText() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("Grace is enough. Q L R _ PRIVATE"),
            .success("Grace is enough. Q LR_PRIVATE"),
        ])
        defer { harness.model.remove() }

        await expectRetryableWithoutLeak(harness, forbidden: ["PRIVATE"])
    }

    @Test func protocolFragmentsNeverReachPresentedTranslation() async throws {
        let source = "她继续。"
        let guidance = [guidance(0, .verifiedFemale)]
        let plan = try makePronounPlan(source: source, guidance: guidance)
        let base = "\(anchored(plan, 0, "she")) continued."
        let namespace = String(plan.occurrences[0].markerName.prefix(12))
        let splitIdentifier = plan.occurrences[0].identifier.map(String.init).joined(separator: " ")
        let fragments = [
            "QLR_PRIVATE", "Q L R _ PRIVATE", namespace,
            plan.occurrences[0].identifier, splitIdentifier, "&lt;/QLR",
        ]
        for fragment in fragments {
            let harness = try await makeTranslationHarness(responses: [
                .success("\(base) \(fragment)"),
                .success("\(base) \(fragment)"),
            ])
            defer { harness.model.remove() }

            await expectRetryableWithoutLeak(
                harness,
                forbidden: [fragment],
                request: TranslationRequest(
                    id: pronounTestRequestID,
                    sourceText: source,
                    glossary: [],
                    pronounGuidance: guidance
                )
            )
        }
    }

}
