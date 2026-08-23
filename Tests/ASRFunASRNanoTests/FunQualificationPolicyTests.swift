@testable import ASRFunASRNano
import ASRQualificationSupport
import Testing

@Suite("Fun-ASR qualification policy")
struct FunQualificationPolicyTests {
    @Test func fairnessConfigurationIsFrozen() {
        let configuration = FunQualificationConfiguration.providerConfiguration
        let metadata = FunQualificationConfiguration.providerMetadata(
            verifiedModelRevision: FunQualificationConfiguration.modelRevision
        )

        #expect(configuration.inferenceThreads == 2)
        #expect(configuration.minimumRMS == 0.003)
        #expect(configuration.maximumNewTokens == 192)
        #expect(configuration.language == "zh")
        #expect(configuration.staticHotwords == FunQualificationConfiguration.hotwords)
        #expect(metadata.settings["inferenceThreads"] == "2")
        #expect(metadata.settings["artifactVerification"] == "sixFilesBytesAndSHA256")
    }

    @Test func inputsRequireFrozenFullCorpusPaths() throws {
        let inputs = try FunQualificationInputs(environment: environment())

        #expect(inputs.modelDirectory.path == "/model")
        #expect(inputs.manifestURL.path == "/qualification-v2.json")
        #expect(inputs.referenceManifestURL.path == "/reference.json")
        #expect(inputs.wavDirectory.path == "/wavs")
        #expect(inputs.reportURL.path == "/report-v3.json")
    }

    @Test func inputsRejectPartialClipAndRuntimeOverrides() {
        for key in [
            "FUNASR_INFERENCE_THREADS",
            "MANDARIN_ASR_MAX_CLIPS",
            "MANDARIN_ASR_PROMPT",
        ] {
            var values = environment()
            values[key] = "override"
            #expect(throws: FunQualificationInputError.unsupportedOverride(key)) {
                try FunQualificationInputs(environment: values)
            }
        }
    }

    @Test func failureCodesAreStableAndRedacted() {
        #expect(
            FunQualificationFailureCode.value(
                for: FunQualificationSegmentError.unknownEndReason
            ) == "qualification.unknown_end_reason"
        )
        #expect(
            FunQualificationFailureCode.value(
                for: FunQualificationSegmentError.unsafeClipID
            ) == "qualification.unsafe_clip_id"
        )
    }

    @Test func attemptRecorderRejectsUnknownEndReasonBeforeProvider() async {
        let definition = ASRQualificationSegmentV2(
            sequence: 1,
            startSample: 0,
            endSample: 1,
            validSampleCount: 1,
            syntheticPaddingSamples: 0,
            endReason: "unrecognized",
            pcmSHA256: String(repeating: "0", count: 64)
        )
        let loaded = ASRQualificationLoadedSegment(
            definition: definition,
            samples: [0.1]
        )
        let provider = FunASRNanoProvider()

        await #expect(throws: FunQualificationSegmentError.unknownEndReason) {
            try await FunQualificationAttemptRecorder.transcribe(
                loaded,
                sampleRate: 16_000,
                provider: provider
            )
        }
    }

    private func environment() -> [String: String] {
        [
            "FUNASR_MODEL_DIR": "/model",
            "MANDARIN_ASR_QUALIFICATION_MANIFEST": "/qualification-v2.json",
            "MANDARIN_ASR_REFERENCE_MANIFEST": "/reference.json",
            "MANDARIN_ASR_WAV_DIR": "/wavs",
            "FUNASR_ASR_REPORT": "/report-v3.json",
        ]
    }
}
