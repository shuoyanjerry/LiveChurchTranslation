import Foundation
import Testing

@Suite("Candidate-pause companion invariants")
struct CandidatePauseSyntheticTests {
    @Test func partialEOFRecordsOnlyValidSamplesAndJoinsEndOfStream() async throws {
        var capture = try CandidatePauseSyntheticCapture()
        try await capture.send(amplitude: 0.1, milliseconds: 300)
        try await capture.send(amplitude: 0, milliseconds: 255)
        let file = try await capture.finish()
        let reached = try #require(file.events.first { $0.reached != nil })
        let evidence = try #require(reached.reached)
        #expect(file.events.count == 2)
        #expect(evidence.thresholdMilliseconds == 250)
        #expect(evidence.candidateEndSourceSample == 8_800)
        #expect(evidence.observationEndSourceSample == 8_880)
        #expect(evidence.overshootSampleCount == 80)
        #expect(reached.resolution.segmentEndReason == "endOfStream")
        #expect(reached.finalizedBoundary.endSample <= Int(file.totalSamples))
    }

    @Test func hardContinuationUsesNewSequenceAndRetainsJoin() async throws {
        var capture = try CandidatePauseSyntheticCapture(
            preferredMaximum: .milliseconds(500),
            maximumGrace: .zero
        )
        try await capture.send(amplitude: 0.1, milliseconds: 520)
        try await capture.send(amplitude: 0, milliseconds: 260)
        let file = try await capture.finish()
        let reached = try #require(file.events.first { $0.reached != nil })
        #expect(reached.sequenceNumber == 2)
        #expect(reached.finalizedBoundary.sequenceNumber == 2)
        #expect(file.finalizedBoundaries.first?.reason == "maximumDuration")
    }

    @Test func resumedSpeechResolvesExactlyOnce() async throws {
        var capture = try CandidatePauseSyntheticCapture()
        try await capture.send(amplitude: 0.1, milliseconds: 300)
        try await capture.send(amplitude: 0, milliseconds: 260)
        try await capture.send(amplitude: 0.1, milliseconds: 40)
        let file = try await capture.finish()
        #expect(file.events.count { $0.kind == "resolved" } == 1)
        #expect(file.events.first?.resolution.kind == "speechResumed")
        #expect(file.events.first?.resolution.segmentEndReason == nil)
    }

    @Test func checkpointAndAggregateCardinalityAreDeterministic() async throws {
        var capture = try CandidatePauseSyntheticCapture()
        try await capture.send(amplitude: 0.1, milliseconds: 300)
        try await capture.send(amplitude: 0, milliseconds: 420)
        let file = try await capture.finish()
        let document = CandidatePauseSyntheticDocument.make(file: file)
        try CandidatePauseDocumentValidator.validate(document)
        #expect(file.events.compactMap(\.reached).map(\.thresholdMilliseconds) == [250, 300, 400])
        #expect(document.aggregate.reachedCount == 3)
        #expect(document.aggregate.resolvedCount == 1)
        #expect(document.aggregate.episodeCount == 1)
    }

    @Test func encodingExcludesPrivateNamesPathsAndTextFields() async throws {
        var capture = try CandidatePauseSyntheticCapture()
        try await capture.send(amplitude: 0.1, milliseconds: 300)
        try await capture.send(amplitude: 0, milliseconds: 260)
        let document = CandidatePauseSyntheticDocument.make(file: try await capture.finish())
        let privateValues = ["speaker-secret.wav", "/private/corpus/speaker-secret.wav"]
        let data = try CandidatePauseReportEncoder.encode(
            document,
            forbiddenValues: privateValues
        )
        let string = try #require(String(data: data, encoding: .utf8))
        #expect(!string.contains("speaker-secret.wav"))
        #expect(!string.contains("fileName"))
        #expect(!string.contains("transcript"))
    }
}
