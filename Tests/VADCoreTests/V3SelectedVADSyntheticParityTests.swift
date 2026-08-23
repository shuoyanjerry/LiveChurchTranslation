import AudioProcessingAPI
import Foundation
import Testing

@Suite("V3 selected WebRTC synthetic parity")
struct V3SelectedVADSyntheticParityTests {
    @Test func selectedLaneMatchesProductionAtEveryFrameAndFlush() async throws {
        let production = try V3SelectedVADDetectorFactory.make()
        let shadow = try V3SelectedVADDetectorFactory.make()
        await production.reset()
        await shadow.reset()
        var traceCount = 0
        var voiceCount = 0
        for (index, amplitude) in amplitudes.enumerated() {
            let frame = ProcessedAudioFrame(
                samples: waveform(amplitude: amplitude, frameIndex: index),
                sampleRate: 16_000,
                timestamp: .milliseconds(index * 20)
            )
            let expected = try await production.process(frame).map(V3SelectedVADVoiceSignature.make)
            let observed = try await shadow.processWithShadowEvidence(frame)
            #expect(expected == observed.voiceEvents.map(V3SelectedVADVoiceSignature.make))
            traceCount += observed.pauseEvents.count
            voiceCount += observed.voiceEvents.count
        }
        let expectedFlush = await production.flush().map(V3SelectedVADVoiceSignature.make)
        let observedFlush = await shadow.flushWithShadowEvidence()
        #expect(expectedFlush == observedFlush.voiceEvents.map(V3SelectedVADVoiceSignature.make))
        #expect(traceCount + observedFlush.pauseEvents.count > 0)
        #expect(voiceCount + observedFlush.voiceEvents.count > 0)
    }

    private var amplitudes: [Float] {
        Array(repeating: 0, count: 5)
            + Array(repeating: 0.12, count: 50)
            + Array(repeating: 0, count: 60)
            + Array(repeating: 0.12, count: 25)
    }

    private func waveform(amplitude: Float, frameIndex: Int) -> [Float] {
        (0..<320).map { offset in
            guard amplitude > 0 else { return 0 }
            let sample = frameIndex * 320 + offset
            return amplitude * Float(sin(2 * Double.pi * 220 * Double(sample) / 16_000))
        }
    }
}
