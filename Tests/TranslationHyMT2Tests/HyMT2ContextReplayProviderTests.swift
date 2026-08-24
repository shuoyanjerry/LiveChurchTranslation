import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2ContextReplayProviderTests {
    @Test func replayedContextGetsOneContextFreeRetry() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success(previousTarget),
            .success(freshTarget),
        ])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(request())
        let prompts = await harness.transport.completionRequests().map(\.prompt)

        #expect(result.targetText == freshTarget)
        #expect(result.review == nil)
        #expect(prompts.count == 2)
        #expect(prompts[0].contains(previousTarget))
        #expect(!prompts[1].contains(previousTarget))
        #expect(!prompts[1].contains(HyMT2PromptControlDelimiter.backgroundOpening))
    }

    @Test func repeatedReplayIsNeverPresentedAsCurrentTranslation() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success(previousTarget),
            .success(previousTarget),
        ])
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(request())
            Issue.record("Expected repeated context replay to fail closed")
        } catch let error as HyMT2Error {
            guard case .invalidOutput(let reasons) = error else {
                Issue.record("Unexpected Hy-MT error: \(error)")
                return
            }
            #expect(reasons.contains("recent translation context was replayed"))
        }

        #expect(await harness.transport.completionRequests().count == 2)
    }

    @Test func freshTranslationCanUseContextNormally() async throws {
        let harness = try await makeTranslationHarness(responses: [.success(freshTarget)])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(request())
        let prompts = await harness.transport.completionRequests().map(\.prompt)

        #expect(result.targetText == freshTarget)
        #expect(prompts.count == 1)
        #expect(prompts[0].contains(previousTarget))
    }

    private func request() -> TranslationRequest {
        TranslationRequest(
            sourceText: currentSource,
            glossary: [],
            context: [
                TranslationContextEntry(
                    sourceText: "先前讲到了信心如何帮助教会面对突如其来的环境变化。",
                    targetText: previousTarget
                )
            ]
        )
    }

    private var currentSource: String {
        "当周围的世界毫无预警地改变时，我们仍要彼此扶持，在祷告中坚定仰望神，"
            + "并忠心走完今天摆在我们面前的道路。"
    }

    private var previousTarget: String {
        "Faith remains our anchor when the world around us changes without warning, "
            + "and prayer keeps the whole church steady."
    }

    private var freshTarget: String {
        "When the world around us changes without warning, we must still support one another, "
            + "look steadfastly to God in prayer, and faithfully walk the path before us today."
    }
}
