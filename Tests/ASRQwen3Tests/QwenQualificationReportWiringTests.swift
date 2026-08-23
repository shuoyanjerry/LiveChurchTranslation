import ASRQualificationSupport
import Foundation
import Testing

@Suite("Qwen qualification Report V3 wiring")
struct QwenQualificationReportWiringTests {
    @Test("records exact provider settings and keeps failures in the SLA denominator")
    func buildsProviderNeutralReport() throws {
        let manifest = QwenQualificationTestFixtures.manifest(referenceText: "他")
        let report = try ASRQualificationReportV3Builder().build(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            qualificationManifestSHA256: String(repeating: "a", count: 64),
            manifest: manifest,
            provider: QwenQualificationConfiguration.providerMetadata(for: .baseline2),
            environment: QwenQualificationTestFixtures.environment,
            clips: [evaluation(referenceText: "他")]
        )

        #expect(report.schemaVersion == 3)
        #expect(report.provider.lane == "productionAdapter")
        #expect(report.provider.modelRevision == "qwen3-asr-0.6b-int8-2026-03-25")
        #expect(report.provider.runtimeRevision == "sherpa-onnx@1.13.6")
        #expect(report.provider.settings["inferenceThreads"] == "2")
        #expect(report.provider.settings["qualificationProfile"] == "baseline2")
        #expect(report.provider.settings["languageCode"] == "zh")
        #expect(report.provider.settings["contextPrompt"] == QwenQualificationConfiguration.prompt)
        #expect(report.aggregate.timing.attemptCount == 2)
        #expect(report.aggregate.timing.failureCount == 1)
        #expect(report.aggregate.timing.withinThreeSecondsRate == 0.5)
        #expect(
            report.clips[0].attempts.map(\.pcmSHA256)
                == manifest.clips[0]
                .segments.map(\.pcmSHA256))
    }

    @Test("lets the shared builder reject altered reference text")
    func rejectsReferenceHashMismatch() {
        let manifest = QwenQualificationTestFixtures.manifest(referenceText: "他")

        #expect(throws: (any Error).self) {
            try ASRQualificationReportV3Builder().build(
                qualificationManifestSHA256: String(repeating: "a", count: 64),
                manifest: manifest,
                provider: QwenQualificationConfiguration.providerMetadata(for: .baseline2),
                environment: QwenQualificationTestFixtures.environment,
                clips: [evaluation(referenceText: "她")]
            )
        }
    }

    private func evaluation(
        referenceText: String
    ) -> ASRQualificationClipEvaluationInputV3 {
        let segments = QwenQualificationTestFixtures.segments
        return ASRQualificationClipEvaluationInputV3(
            id: "fixture-clip",
            referenceText: referenceText,
            sourceAudioSeconds: 10,
            segments: segments,
            attempts: [
                attempt(segments[0], elapsed: 2, hypothesis: "他"),
                failure(segments[1], elapsed: 4),
            ]
        )
    }

    private func attempt(
        _ segment: ASRQualificationSegmentV2,
        elapsed: Double,
        hypothesis: String
    ) -> ASRQualificationAttemptV3 {
        ASRQualificationAttemptV3(
            sequence: segment.sequence,
            inputSampleCount: segment.validSampleCount,
            pcmSHA256: segment.pcmSHA256,
            elapsedSeconds: elapsed,
            status: .success,
            hypothesis: hypothesis
        )
    }

    private func failure(
        _ segment: ASRQualificationSegmentV2,
        elapsed: Double
    ) -> ASRQualificationAttemptV3 {
        ASRQualificationAttemptV3(
            sequence: segment.sequence,
            inputSampleCount: segment.validSampleCount,
            pcmSHA256: segment.pcmSHA256,
            elapsedSeconds: elapsed,
            status: .failure,
            failureCode: "asr.filtered_nonspeech"
        )
    }
}
