import ASRQualificationSupport
import Foundation
import Testing

@Suite("ASR qualification character metrics")
struct ASRCharacterErrorMetricsTests {
    @Test("normalizes case and removes non-alphanumeric characters")
    func normalization() {
        let metric = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: " A-1，救恩! ",
            hypothesis: "a1救因"
        )

        #expect(metric.editCount == 1)
        #expect(metric.referenceCharacterCount == 4)
        #expect(metric.rate == 0.25)
    }

    @Test("strict CER charges hypothesis edges")
    func strictEdges() {
        let metric = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: "救恩",
            hypothesis: "前救恩后"
        )

        #expect(metric.editCount == 2)
        #expect(metric.rate == 1)
    }

    @Test("edge-free semiglobal CER ignores only hypothesis edges")
    func edgeFreeSemiglobal() {
        let edgeOnly = ASRQualificationTextMetrics.normalizedEdgeFreeSemiglobalCER(
            reference: "救恩本乎恩典",
            hypothesis: "开场救恩本乎恩典结束"
        )
        let interior = ASRQualificationTextMetrics.normalizedEdgeFreeSemiglobalCER(
            reference: "救恩本乎恩典",
            hypothesis: "开场救恩出于恩典结束"
        )

        #expect(edgeOnly.editCount == 0)
        #expect(interior.editCount == 2)
        #expect(interior.rate == 2.0 / 6.0)
    }

    @Test("edge-free semiglobal CER still charges missing reference text")
    func edgeFreeMissingReferenceText() {
        let metric = ASRQualificationTextMetrics.normalizedEdgeFreeSemiglobalCER(
            reference: "救恩本乎恩典",
            hypothesis: "救恩恩典"
        )

        #expect(metric.editCount == 2)
    }

    @Test("zero-reference rate convention is explicit")
    func zeroReference() {
        let empty = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: " ! ",
            hypothesis: ""
        )
        let insertion = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: "",
            hypothesis: "甲乙"
        )
        let edgeFree = ASRQualificationTextMetrics.normalizedEdgeFreeSemiglobalCER(
            reference: "",
            hypothesis: "甲乙"
        )

        #expect(empty.editCount == 0)
        #expect(empty.rate == 0)
        #expect(insertion.editCount == 2)
        #expect(insertion.rate == 1)
        #expect(edgeFree.editCount == 0)
        #expect(edgeFree.rate == 0)
    }

    @Test("measurement is report-codable including rate")
    func codableMeasurement() throws {
        let metric = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: "救恩",
            hypothesis: "救因"
        )

        let data = try JSONEncoder().encode(metric)
        let decoded = try JSONDecoder().decode(ASRCharacterErrorMeasurement.self, from: data)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(decoded == metric)
        #expect(json.contains("\"rate\":"))
    }

    @Test("English WER normalizes punctuation, case, and apostrophes")
    func englishWERNormalization() {
        let metric = ASRQualificationTextMetrics.normalizedEnglishWER(
            reference: "Christ’s church isn't abandoned.",
            hypothesis: "CHRISTS CHURCH ISNT ABANDONED"
        )

        #expect(metric.editCount == 0)
        #expect(metric.referenceWordCount == 4)
        #expect(metric.rate == 0)
    }

    @Test("English WER charges insertions, deletions, and substitutions")
    func englishWEREdits() {
        let metric = ASRQualificationTextMetrics.normalizedEnglishWER(
            reference: "grace through faith alone",
            hypothesis: "great faith and hope"
        )

        #expect(metric.editCount == 4)
        #expect(metric.referenceWordCount == 4)
        #expect(metric.rate == 1)
    }
}
