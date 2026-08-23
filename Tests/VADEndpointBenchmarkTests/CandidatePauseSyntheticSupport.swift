import AudioProcessingAPI
import VADAPI
import VADCore

struct CandidatePauseSyntheticCapture {
    private let detector: CalibratedVoiceActivityDetector
    private var state = CandidatePauseReplayState()
    private let recorder = VADBoundaryRecorder(sampleRate: 16_000)

    init(
        preferredMaximum: Duration = .seconds(15),
        maximumGrace: Duration = .milliseconds(1_500)
    ) throws {
        detector = try CalibratedVoiceActivityDetector(
            classifier: CandidatePauseFixedClassifier(),
            configuration: VoiceActivityConfiguration(
                analysisWindow: .milliseconds(20),
                preRoll: .milliseconds(20),
                speechStart: .milliseconds(20),
                trailingSilence: .milliseconds(650),
                shortUtterance: .milliseconds(40),
                shortTrailingSilence: .milliseconds(650),
                softSplitSilence: .milliseconds(500),
                softSplitAfter: .seconds(9),
                preferredMaximumSegment: preferredMaximum,
                maximumBoundaryGrace: maximumGrace,
                postRoll: .milliseconds(280),
                minimumVoiced: .milliseconds(40),
                decisionWindowCount: 1,
                decisionSpeechVotes: 1
            )
        )
    }

    mutating func send(amplitude: Float, milliseconds: Int) async throws {
        let sampleCount = milliseconds * 16
        let frame = ProcessedAudioFrame(
            samples: Array(repeating: amplitude, count: sampleCount),
            sampleRate: 16_000,
            timestamp: .seconds(Double(state.consumedSamples) / 16_000)
        )
        let observed = try await detector.processWithShadowEvidence(frame)
        state.consumedSamples += sampleCount
        append(observed)
    }

    mutating func finish() async throws -> CandidatePauseFileReport {
        let remainder = state.consumedSamples % 320
        append(
            await detector.flushWithShadowEvidence(),
            syntheticPaddingSamples: remainder == 0 ? 0 : 320 - remainder
        )
        let events = try state.pauseRecorder.finalized(boundaries: state.boundaries)
        return CandidatePauseFileReport(
            clipID: "sermon-01",
            sourceWAVSHA256: String(repeating: "a", count: 64),
            sourceWAVByteCount: Int64(max(1, state.consumedSamples * 4)),
            totalSamples: Int64(state.consumedSamples),
            audioSeconds: Double(state.consumedSamples) / 16_000,
            sourceBoundaryCount: state.boundaries.count,
            sourceEOFPaddingSamples: 0,
            sourceEOFLagCount: 0,
            finalizedBoundaries: state.boundaries.map(CandidatePauseFinalizedBoundary.init),
            events: events
        )
    }

    private mutating func append(
        _ observed: ObservedVoiceActivityBatch,
        syntheticPaddingSamples: Int = 0
    ) {
        recorder.append(
            observed.voiceEvents,
            emittedAtSample: state.consumedSamples,
            syntheticPaddingSamples: syntheticPaddingSamples,
            to: &state.boundaries
        )
        state.pauseRecorder.append(
            observed.pauseEvents,
            emittedAfterSourceSample: Int64(state.consumedSamples)
        )
    }
}

struct CandidatePauseFixedClassifier: VoiceActivityClassifying {
    mutating func isSpeech(_ samples: [Float], whileSpeaking _: Bool) -> Bool {
        samples.contains { abs($0) >= 0.05 }
    }

    mutating func reset() {}
}

enum CandidatePauseSyntheticDocument {
    static func make(file: CandidatePauseFileReport) -> CandidatePauseBenchmarkDocument {
        let files = [file]
        return CandidatePauseBenchmarkDocument(
            frameSampleCount: 320,
            sampleRateHz: 16_000,
            provenance: CandidatePauseProvenance(
                sourceReportSHA256: String(repeating: "b", count: 64),
                sourceReportByteCount: 1,
                selectedConfigurationSHA256: String(repeating: "c", count: 64),
                productionVADSourceSHA256: String(repeating: "d", count: 64),
                productionVADSourceFileCount: 1,
                companionSourceSHA256: String(repeating: "e", count: 64),
                companionSourceFileCount: 1
            ),
            runtimeCaveats: ["synthetic"],
            files: files,
            aggregate: CandidatePauseAggregateBuilder.make(files: files)
        )
    }
}
