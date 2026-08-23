import Foundation
import ScriptureQualificationSupport
import Testing

@Suite struct ScripturePunctuationFidelityTests {
    @Test func exactPunctuationAndPlacementPass() throws {
        let result = try ScripturePunctuationFidelityMetric.measure(
            reference: "Original, synthetic—text.",
            hypothesis: "Original, synthetic—text."
        )

        #expect(result.referencePunctuationCount == 3)
        #expect(result.anchoredEditDistance == 0)
        #expect(result.errorRate == 0)
        #expect(result.isExact)
    }

    @Test func detectsMovedMarkEvenWhenPunctuationSequenceMatches() throws {
        let result = try ScripturePunctuationFidelityMetric.measure(
            reference: "ab,c",
            hypothesis: "a,bc"
        )

        #expect(result.referencePunctuationCount == 1)
        #expect(result.hypothesisPunctuationCount == 1)
        #expect(result.anchoredEditDistance == 1)
        #expect(!result.isExact)
    }

    @Test func doesNotExposeSourceTextInAggregateResult() throws {
        let result = try ScripturePunctuationFidelityMetric.measure(
            reference: "private synthetic source!",
            hypothesis: "private synthetic source"
        )
        let data = try JSONEncoder().encode(result)
        let encoded = try #require(String(data: data, encoding: .utf8))

        #expect(result.errorRate == 1)
        #expect(!encoded.contains("private"))
        #expect(!encoded.contains("source"))
    }
}
