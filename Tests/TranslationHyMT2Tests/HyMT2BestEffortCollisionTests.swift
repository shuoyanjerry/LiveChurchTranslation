import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2BestEffortCollisionTests {
    @Test func ordinaryIdentifiersRemainVisibleWithoutPronounProtocol() async throws {
        let expected = "Read P3, P0001, AP0001B, P00010, and <Question> next."
        let harness = try await makeTranslationHarness(responses: [.success(expected)])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(sourceText: "请读下一项。", glossary: [])
        )

        #expect(result.targetText == expected)
        #expect(result.review == nil)
    }

    @Test func ordinarySQLTextDoesNotCollideWithReservedPrefix() async throws {
        let expected = "SQL rules are important."
        let harness = try await makeTranslationHarness(responses: [.success(expected)])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(sourceText: "SQL 规则很重要。", glossary: [])
        )

        #expect(result.targetText == expected)
    }

    @Test func ordinaryIdentifiersRemainVisibleAlongsidePronounGuidance() async throws {
        let source = "她让我们读 P3、AP0001B、P00010 和下一项。"
        let plan = try makePronounPlan(
            source: source,
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output =
            "\(anchored(plan, 0, "She")) asked us to read P3, AP0001B, P00010, and <Question>."
        let harness = try await makeTranslationHarness(responses: [.success(output)])
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(
            TranslationRequest(
                id: pronounTestRequestID,
                sourceText: source,
                glossary: [],
                pronounGuidance: [guidance(0, .verifiedFemale)]
            )
        )

        #expect(
            result.targetText
                == "She asked us to read P3, AP0001B, P00010, and <Question>."
        )
    }
}
