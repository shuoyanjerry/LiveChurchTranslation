import AVFoundation
import AudioProcessingAPI
import Foundation
import VADAPI

struct VADBenchmarkRunner {
    private let sampleRate = 16_000.0
    private let frameSampleCount = 320
    private let boundaryRecorder = VADBoundaryRecorder(sampleRate: 16_000)

    func replay(
        _ entry: VADCorpusEntry,
        strategy: VADBenchmarkStrategy
    ) async throws -> VADFileReport {
        let sourceFingerprint = try VADBenchmarkCorpus.fingerprint(entry.url)
        let file = try AVAudioFile(forReading: entry.url)
        try validateFormat(of: file, corpusID: entry.id)
        let detector = try strategy.makeDetector()
        let wallClock = ContinuousClock()
        let wallStart = wallClock.now
        var state = ReplayState()
        try await replayFrames(
            from: file,
            corpusID: entry.id,
            with: detector,
            measuredBy: wallClock,
            state: &state
        )
        await finishReplay(detector, measuredBy: wallClock, state: &state)
        guard Int64(state.consumedSamples) == file.length else {
            throw VADBenchmarkError.incompleteAudioRead(entry.id)
        }
        let finalFingerprint = try VADBenchmarkCorpus.fingerprint(entry.url)
        guard finalFingerprint == sourceFingerprint else {
            throw VADBenchmarkError.audioIdentityChanged(entry.id)
        }
        return makeReport(
            entry: entry,
            fingerprint: sourceFingerprint,
            totalSamples: file.length,
            replayWallSeconds: wallStart.duration(to: wallClock.now).secondsValue,
            state: state
        )
    }
}

extension VADBenchmarkRunner {
    private func validateFormat(of file: AVAudioFile, corpusID: String) throws {
        guard file.processingFormat.sampleRate == sampleRate,
            file.processingFormat.channelCount == 1
        else { throw VADBenchmarkError.invalidAudioFormat(corpusID) }
    }

    private func replayFrames(
        from file: AVAudioFile,
        corpusID: String,
        with detector: any VoiceActivityDetector,
        measuredBy wallClock: ContinuousClock,
        state: inout ReplayState
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
                throw VADBenchmarkError.incompleteAudioRead(corpusID)
            }
            try await replay(samples, with: detector, measuredBy: wallClock, state: &state)
        }
    }

    private func replay(
        _ samples: [Float],
        with detector: any VoiceActivityDetector,
        measuredBy wallClock: ContinuousClock,
        state: inout ReplayState
    ) async throws {
        for start in stride(from: 0, to: samples.count, by: frameSampleCount) {
            let end = min(start + frameSampleCount, samples.count)
            let frameSamples = Array(samples[start..<end])
            let frame = ProcessedAudioFrame(
                samples: frameSamples,
                sampleRate: sampleRate,
                timestamp: duration(for: state.consumedSamples)
            )
            let started = wallClock.now
            let events = try await detector.process(frame)
            state.processingSeconds += started.duration(to: wallClock.now).secondsValue
            state.consumedSamples += frameSamples.count
            boundaryRecorder.append(
                events,
                emittedAtSample: state.consumedSamples,
                syntheticPaddingSamples: 0,
                to: &state.boundaries
            )
        }
    }

    private func finishReplay(
        _ detector: any VoiceActivityDetector,
        measuredBy wallClock: ContinuousClock,
        state: inout ReplayState
    ) async {
        let flushStarted = wallClock.now
        let finalEvents = await detector.flush()
        state.processingSeconds += flushStarted.duration(to: wallClock.now).secondsValue
        let remainder = state.consumedSamples % frameSampleCount
        boundaryRecorder.append(
            finalEvents,
            emittedAtSample: state.consumedSamples,
            syntheticPaddingSamples: remainder == 0 ? 0 : frameSampleCount - remainder,
            to: &state.boundaries
        )
    }

    private func makeReport(
        entry: VADCorpusEntry,
        fingerprint: VADAudioFingerprint,
        totalSamples: Int64,
        replayWallSeconds: Double,
        state: ReplayState
    ) -> VADFileReport {
        VADFileReport(
            corpusID: entry.id,
            fileName: entry.fileName,
            sha256: fingerprint.sha256,
            byteCount: fingerprint.byteCount,
            sampleRateHz: Int(sampleRate),
            totalSamples: totalSamples,
            audioSeconds: Double(totalSamples) / sampleRate,
            detectorProcessingSeconds: state.processingSeconds,
            replayWallSeconds: replayWallSeconds,
            boundaries: state.boundaries
        )
    }

    private func duration(for sampleCount: Int) -> Duration {
        .seconds(Double(sampleCount) / sampleRate)
    }
}

private struct ReplayState {
    var processingSeconds = 0.0
    var boundaries: [VADBoundaryRecord] = []
    var consumedSamples = 0
}
