import AVFoundation
import AudioProcessingAPI
import Foundation
import VADCore

struct V3SelectedVADWAVReplay {
    func run(_ track: V3SelectedVADPreparedTrack) async throws -> V3SelectedVADTrackMetrics {
        let sourceBefore = try V3SelectedVADHashing.fingerprint(track.url)
        guard sourceBefore == track.fingerprint else { throw V3SelectedVADError.invalidWAV }
        let production = try V3SelectedVADDetectorFactory.make()
        let shadow = try V3SelectedVADDetectorFactory.make()
        await production.reset()
        await shadow.reset()
        let file = try AVAudioFile(forReading: track.url)
        try validate(file, expected: track.expected)
        var state = V3SelectedVADReplayState()
        try await replayFile(file, production: production, shadow: shadow, state: &state)
        try await flush(production: production, shadow: shadow, state: &state)
        guard state.consumedSamples == track.expected.exactSampleFrames else {
            throw V3SelectedVADError.incompleteRead
        }
        guard try V3SelectedVADHashing.fingerprint(track.url) == sourceBefore else {
            throw V3SelectedVADError.unsafeInput
        }
        return try state.metrics()
    }

    private func validate(
        _ file: AVAudioFile,
        expected: V3SelectedVADManifestTrack
    ) throws {
        guard file.processingFormat.sampleRate == 16_000,
            file.processingFormat.channelCount == 1,
            file.fileFormat.sampleRate == 16_000,
            file.fileFormat.channelCount == 1,
            file.length == expected.exactSampleFrames
        else { throw V3SelectedVADError.invalidWAV }
    }

    private func flush(
        production: CalibratedVoiceActivityDetector,
        shadow: CalibratedVoiceActivityDetector,
        state: inout V3SelectedVADReplayState
    ) async throws {
        let productionEvents = await production.flush().map(V3SelectedVADVoiceSignature.make)
        let shadowBatch = await shadow.flushWithShadowEvidence()
        let shadowEvents = shadowBatch.voiceEvents.map(V3SelectedVADVoiceSignature.make)
        try state.append(production: productionEvents, shadow: shadowEvents)
        state.traceCounter.append(shadowBatch.pauseEvents)
    }
}
