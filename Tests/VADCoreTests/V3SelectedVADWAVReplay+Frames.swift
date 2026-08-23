import AVFoundation
import AudioProcessingAPI
import VADCore

extension V3SelectedVADWAVReplay {
    func replayFile(
        _ file: AVAudioFile,
        production: CalibratedVoiceActivityDetector,
        shadow: CalibratedVoiceActivityDetector,
        state: inout V3SelectedVADReplayState
    ) async throws {
        let capacity: AVAudioFrameCount = 16_000
        while file.framePosition < file.length {
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: capacity
                )
            else { throw V3SelectedVADError.invalidWAV }
            try file.read(into: buffer)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else {
                throw V3SelectedVADError.incompleteRead
            }
            let samples = Array(
                UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
            )
            try await replaySamples(
                samples,
                production: production,
                shadow: shadow,
                state: &state
            )
        }
    }

    private func replaySamples(
        _ samples: [Float],
        production: CalibratedVoiceActivityDetector,
        shadow: CalibratedVoiceActivityDetector,
        state: inout V3SelectedVADReplayState
    ) async throws {
        for start in stride(from: 0, to: samples.count, by: 320) {
            let end = min(start + 320, samples.count)
            let frameSamples = Array(samples[start..<end])
            let frame = ProcessedAudioFrame(
                samples: frameSamples,
                sampleRate: 16_000,
                timestamp: .milliseconds(state.consumedSamples / 16)
            )
            let productionEvents = try await production.process(frame)
                .map(V3SelectedVADVoiceSignature.make)
            let shadowBatch = try await shadow.processWithShadowEvidence(frame)
            let shadowEvents = shadowBatch.voiceEvents.map(V3SelectedVADVoiceSignature.make)
            try state.append(production: productionEvents, shadow: shadowEvents)
            state.traceCounter.append(shadowBatch.pauseEvents)
            state.consumedSamples += Int64(frameSamples.count)
        }
    }
}
