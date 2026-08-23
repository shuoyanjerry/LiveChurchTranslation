import ASRQualificationSupport
import Foundation
import Testing

@Suite("ASR qualification report V3 aggregation")
struct ReportV3AggregationTests {
    @Test func microAggregatesCERAndPronounPairs() throws {
        let report = try aggregateReport()
        let aggregate = report.aggregate

        #expect(aggregate.strictCER.editCount == 3)
        #expect(aggregate.strictCER.referenceCharacterCount == 5)
        #expect(aggregate.strictCER.rate == 0.6)
        #expect(aggregate.strictPronounConfusion.referenceTotal == 4)
        #expect(aggregate.strictPronounConfusion.hypothesisTotal == 4)
        #expect(aggregate.strictPronounConfusion.correctTotal == 3)
        #expect(aggregate.strictPronounConfusion.substitutionTotal == 1)
        #expect(aggregate.strictPronounConfusion.count(reference: "他", hypothesis: "他") == 2)
        #expect(aggregate.strictPronounConfusion.count(reference: "它", hypothesis: "祂") == 1)
    }

    @Test func edgeFreeAggregateRequiresEveryClipToBeEligible() throws {
        let eligible = try aggregateReport(strictEligible: true).aggregate.edgeFreeSemiglobalCER
        #expect(eligible?.editCount == 1)
        #expect(eligible?.referenceCharacterCount == 5)
        #expect(eligible?.rate == 0.2)

        let mixed = try aggregateReport()
        #expect(mixed.aggregate.edgeFreeSemiglobalCER == nil)
        #expect(mixed.clips[0].edgeFreeSemiglobalCER != nil)
        #expect(mixed.clips[1].edgeFreeSemiglobalCER == nil)
    }

    @Test func unionCoverageDoesNotDoubleCountOverlapOrPadding() throws {
        let report = try aggregateReport()
        #expect(report.aggregate.sourceAudioSeconds == 15)
        #expect(report.aggregate.decodedInputSeconds == 14)
        #expect(report.aggregate.unionCoveredSourceSeconds == 11)
        #expect(report.clips[0].decodedInputSeconds == 9)
        #expect(report.clips[0].unionCoveredSourceSeconds == 6)
    }

    @Test func failuresRemainInTimingAndLatencyDenominators() throws {
        let report = try aggregateReport()
        let timing = report.aggregate.timing

        #expect(timing.attemptCount == 4)
        #expect(timing.successCount == 3)
        #expect(timing.failureCount == 1)
        #expect(timing.successfulAttemptLatencyP50Seconds == 2)
        #expect(timing.successfulAttemptLatencyP95Seconds == 4)
        #expect(timing.allAttemptLatencyP50Seconds == 4)
        #expect(timing.allAttemptLatencyP95Seconds == 10)
        #expect(timing.withinThreeSecondsRate == 0.5)
        #expect(timing.decodeSeconds == 17)
        #expect(timing.realTimeFactor == 17.0 / 14.0)
        #expect(report.clips[0].timing.successfulAttemptLatencyP50Seconds == 4)
    }

    @Test func preservesAttemptsAndRoundTripsCodable() throws {
        let report = try aggregateReport()
        #expect(report.schemaVersion == 3)
        #expect(report.clips.map(\.id) == ["edge", "strict"])
        #expect(report.clips.map(\.hypothesisText) == ["噪他\n甲音", "他她祂"])
        #expect(report.clips[1].attempts[1].failureCode == "decode")

        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(ASRQualificationReportV3.self, from: data)
        #expect(decoded == report)
    }
}

private func aggregateReport(strictEligible: Bool = false) throws -> ASRQualificationReportV3 {
    let fixture = aggregateFixture(strictEligible: strictEligible)
    return try ASRQualificationReportV3Builder().build(
        generatedAt: Date(timeIntervalSince1970: 1_000),
        qualificationManifestSHA256: testHash,
        manifest: fixture.manifest,
        provider: reportProvider,
        environment: reportEnvironment,
        clips: fixture.inputs
    )
}

private func aggregateFixture(
    strictEligible: Bool
) -> (manifest: ASRQualificationManifestV2, inputs: [ASRQualificationClipEvaluationInputV3]) {
    let edge = edgeSegments()
    let strict = strictSegments()
    return (
        aggregateManifest(edge: edge, strict: strict, strictEligible: strictEligible),
        aggregateInputs(edge: edge, strict: strict)
    )
}

private func edgeSegments() -> [ASRQualificationSegmentV2] {
    [
        testSegment(
            sequence: 1, start: 0, end: 40, valid: 40, padding: 10,
            pcmSHA256: String(repeating: "1", count: 64)),
        testSegment(
            sequence: 2, start: 20, end: 60, valid: 40,
            pcmSHA256: String(repeating: "2", count: 64)),
    ]
}

private func strictSegments() -> [ASRQualificationSegmentV2] {
    [
        testSegment(
            sequence: 1, start: 0, end: 20, valid: 20,
            pcmSHA256: String(repeating: "3", count: 64)),
        testSegment(
            sequence: 2, start: 20, end: 50, valid: 30,
            pcmSHA256: String(repeating: "4", count: 64)),
    ]
}

private func aggregateManifest(
    edge: [ASRQualificationSegmentV2],
    strict: [ASRQualificationSegmentV2],
    strictEligible: Bool
) -> ASRQualificationManifestV2 {
    testManifest(clips: [
        testClip(
            id: "edge", sampleRate: 10, totalSamples: 100,
            referenceSHA256: referenceHash("他甲"),
            allowsHypothesisEdgeInsertions: true, segments: edge),
        testClip(
            id: "strict", sampleRate: 10, totalSamples: 50,
            referenceSHA256: referenceHash("他她它"),
            allowsHypothesisEdgeInsertions: strictEligible, segments: strict),
    ])
}

private func aggregateInputs(
    edge: [ASRQualificationSegmentV2],
    strict: [ASRQualificationSegmentV2]
) -> [ASRQualificationClipEvaluationInputV3] {
    [
        aggregateInput(
            id: "edge", reference: "他甲", seconds: 10, segments: edge,
            attempts: [
                reportAttempt(edge[0], elapsedSeconds: 1, hypothesis: "噪他"),
                reportAttempt(edge[1], elapsedSeconds: 4, hypothesis: "甲音"),
            ]),
        aggregateInput(
            id: "strict", reference: "他她它", seconds: 5, segments: strict,
            attempts: [
                reportAttempt(strict[0], elapsedSeconds: 2, hypothesis: "他她祂"),
                reportAttempt(
                    strict[1], elapsedSeconds: 10, status: .failure,
                    hypothesis: nil, failureCode: "decode"),
            ]),
    ]
}

private func aggregateInput(
    id: String,
    reference: String,
    seconds: Double,
    segments: [ASRQualificationSegmentV2],
    attempts: [ASRQualificationAttemptV3]
) -> ASRQualificationClipEvaluationInputV3 {
    ASRQualificationClipEvaluationInputV3(
        id: id, referenceText: reference, sourceAudioSeconds: seconds,
        segments: segments, attempts: attempts
    )
}
