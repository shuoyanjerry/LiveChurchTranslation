import Foundation
import Testing
import VADAPI

@Suite struct VADBenchmarkReportTests {
    @Test func perFileMetricsAreEncoded() throws {
        let file = VADFileReport(
            corpusID: "sermon-01",
            fileName: "sermon-01.wav",
            sha256: "abc",
            byteCount: 320,
            sampleRateHz: 16_000,
            totalSamples: 16_000,
            audioSeconds: 1,
            detectorProcessingSeconds: 0.01,
            replayWallSeconds: 0.02,
            boundaries: [boundary(reason: "maximumDuration")]
        )

        let data = try JSONEncoder().encode(file)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let metrics = try #require(object["metrics"] as? [String: Any])
        let boundaries = try #require(object["boundaries"] as? [[String: Any]])
        let firstBoundary = try #require(boundaries.first)
        #expect(metrics["segmentCount"] as? Int == 1)
        #expect(metrics["forcedHardCutProxyCount"] as? Int == 1)
        #expect(firstBoundary["signedEmissionOffsetFromRetainedAudioSeconds"] as? Double == 0)
        #expect(firstBoundary["signedEmissionOffsetSeconds"] == nil)
        #expect(object["fileName"] as? String == "sermon-01.wav")
        #expect(object["sampleRateHz"] as? Int == 16_000)
        #expect(object["totalSamples"] as? Int == 16_000)
    }

    @Test func emptyMetricsDoNotInventPercentiles() {
        let metrics = VADMetricsReport(
            audioSeconds: 1,
            processingSeconds: 0,
            boundaries: []
        )

        #expect(metrics.segmentDurationSeconds.p50 == nil)
        #expect(metrics.emissionLagAfterRetainedAudioSeconds.p95 == nil)
    }

    @Test func syntheticPartialWindowRetainsSignedNegativeOffset() throws {
        let segment = SpeechSegment(
            sequenceNumber: 1,
            samples: [Float](repeating: 0.1, count: 320),
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .endOfStream
        )
        var values: [VADBoundaryRecord] = []
        VADBoundaryRecorder(sampleRate: 16_000).append(
            [.speechEnded(segment)],
            emittedAtSample: 160,
            syntheticPaddingSamples: 160,
            to: &values
        )

        let record = try #require(values.first)
        #expect(abs(record.signedEmissionOffsetSeconds + 0.01) < 0.000_001)
        #expect(record.emissionLagAfterRetainedAudioSeconds == nil)
        #expect(record.syntheticPaddingSamplesAtEmission == 160)
        #expect(record.startSample == 0)
        #expect(record.endSample == 320)
        #expect(record.validSampleCount == 320)
        #expect(record.pcmSHA256.count == 64)
    }

    private func boundary(reason: String) -> VADBoundaryRecord {
        VADBoundaryRecord(
            sequenceNumber: 1,
            startSample: 0,
            endSample: 16_000,
            validSampleCount: 16_000,
            pcmSHA256: String(repeating: "a", count: 64),
            startedAtSeconds: 0,
            endedAtSeconds: 1,
            durationSeconds: 1,
            reason: reason,
            signedEmissionOffsetSeconds: 0,
            emissionLagAfterRetainedAudioSeconds: 0,
            syntheticPaddingSamplesAtEmission: 0
        )
    }
}
