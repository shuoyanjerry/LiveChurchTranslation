import AVFoundation
import AudioProcessingAPI
import Foundation
import VADAPI
import VADCore

struct CandidatePauseBenchmarkRunner {
    private let sampleRate = 16_000.0
    private let frameSampleCount = 320
    private let boundaryRecorder = VADBoundaryRecorder(sampleRate: 16_000)

    func replay(
        _ entry: VADCorpusEntry,
        source: CandidatePauseSourceFile
    ) async throws -> CandidatePauseFileReport {
        let sourceFingerprint = try VADBenchmarkCorpus.fingerprint(entry.url)
        let file = try AVAudioFile(forReading: entry.url)
        try validate(file: file, source: source, entry: entry)
        let detector = try VADBenchmarkStrategy.makeSelectedShadowDetector()
        var state = CandidatePauseReplayState()
        try await replayFrames(from: file, detector: detector, state: &state)
        await flush(detector, state: &state)
        let reconciliation = try validateCompletedReplay(
            state: state,
            file: file,
            entry: entry,
            fingerprint: sourceFingerprint,
            source: source
        )
        let events = try state.pauseRecorder.finalized(boundaries: state.boundaries)
        return CandidatePauseFileReport(
            clipID: source.corpusID,
            sourceWAVSHA256: sourceFingerprint.sha256,
            sourceWAVByteCount: sourceFingerprint.byteCount,
            totalSamples: file.length,
            audioSeconds: Double(file.length) / sampleRate,
            sourceBoundaryCount: source.boundaries.count,
            sourceEOFPaddingSamples: reconciliation.paddingSamples,
            sourceEOFLagCount: reconciliation.emissionLagCount,
            finalizedBoundaries: state.boundaries.map(CandidatePauseFinalizedBoundary.init),
            events: events
        )
    }

    private func replayFrames(
        from file: AVAudioFile,
        detector: CalibratedVoiceActivityDetector,
        state: inout CandidatePauseReplayState
    ) async throws {
        let capacity: AVAudioFrameCount = 16_000
        while file.framePosition < file.length {
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: capacity
                )
            else { throw VADBenchmarkError.unsupportedPCMFormat }
            try file.read(into: buffer)
            let samples = try VADBenchmarkCorpus.samples(from: buffer)
            guard !samples.isEmpty else {
                throw VADBenchmarkError.incompleteAudioRead("private clip")
            }
            try await replay(samples, detector: detector, state: &state)
        }
    }

    private func replay(
        _ samples: [Float],
        detector: CalibratedVoiceActivityDetector,
        state: inout CandidatePauseReplayState
    ) async throws {
        for start in stride(from: 0, to: samples.count, by: frameSampleCount) {
            let end = min(start + frameSampleCount, samples.count)
            let frameSamples = Array(samples[start..<end])
            let frame = ProcessedAudioFrame(
                samples: frameSamples,
                sampleRate: sampleRate,
                timestamp: duration(for: state.consumedSamples)
            )
            let observed = try await detector.processWithShadowEvidence(frame)
            state.consumedSamples += frameSamples.count
            append(observed, syntheticPaddingSamples: 0, state: &state)
        }
    }

    private func flush(
        _ detector: CalibratedVoiceActivityDetector,
        state: inout CandidatePauseReplayState
    ) async {
        let observed = await detector.flushWithShadowEvidence()
        let remainder = state.consumedSamples % frameSampleCount
        append(
            observed,
            syntheticPaddingSamples: remainder == 0 ? 0 : frameSampleCount - remainder,
            state: &state
        )
    }

    private func append(
        _ observed: ObservedVoiceActivityBatch,
        syntheticPaddingSamples: Int,
        state: inout CandidatePauseReplayState
    ) {
        boundaryRecorder.append(
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

extension CandidatePauseBenchmarkRunner {
    private func validate(
        file: AVAudioFile,
        source: CandidatePauseSourceFile,
        entry: VADCorpusEntry
    ) throws {
        guard file.processingFormat.sampleRate == sampleRate,
            file.processingFormat.channelCount == 1
        else { throw VADBenchmarkError.invalidAudioFormat(entry.id) }
        let seconds = Double(file.length) / sampleRate
        guard approximatelyEqual(seconds, source.audioSeconds) else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("audio duration mismatch")
        }
    }

    private func validateCompletedReplay(
        state: CandidatePauseReplayState,
        file: AVAudioFile,
        entry: VADCorpusEntry,
        fingerprint: VADAudioFingerprint,
        source: CandidatePauseSourceFile
    ) throws -> CandidatePauseSourceReconciliation {
        guard Int64(state.consumedSamples) == file.length else {
            throw VADBenchmarkError.incompleteAudioRead(entry.id)
        }
        guard try VADBenchmarkCorpus.fingerprint(entry.url) == fingerprint else {
            throw VADBenchmarkError.audioIdentityChanged(entry.id)
        }
        return try CandidatePauseSourceBoundaryValidator.validate(
            actual: state.boundaries,
            expected: source.boundaries,
            sourceAudioSeconds: source.audioSeconds
        )
    }

    private func duration(for sampleCount: Int) -> Duration {
        .seconds(Double(sampleCount) / sampleRate)
    }

    private func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.000_000_001
    }
}

struct CandidatePauseReplayState {
    var boundaries: [VADBoundaryRecord] = []
    var pauseRecorder = CandidatePauseRecorder()
    var consumedSamples = 0
}
