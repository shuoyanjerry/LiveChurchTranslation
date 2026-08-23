import AudioProcessingAPI
import CryptoKit
import Foundation
import Testing
import VADAPI

@Suite("Selected WebRTC candidate-pause parity")
struct SelectedLaneParityTests {
    @Test func productionAndShadowVoiceSignaturesMatchPerFrameAndFlush() async throws {
        let production = try VADBenchmarkStrategy.makeSelectedShadowDetector()
        let shadow = try VADBenchmarkStrategy.makeSelectedShadowDetector()
        let frames = Self.frames()
        var pauseEventCount = 0
        var voiceEventCount = 0
        for frame in frames {
            let expected = try await production.process(frame)
            let observed = try await shadow.processWithShadowEvidence(frame)
            #expect(Self.signatures(expected) == Self.signatures(observed.voiceEvents))
            pauseEventCount += observed.pauseEvents.count
            voiceEventCount += observed.voiceEvents.count
        }
        let expectedFlush = await production.flush()
        let observedFlush = await shadow.flushWithShadowEvidence()
        #expect(Self.signatures(expectedFlush) == Self.signatures(observedFlush.voiceEvents))
        pauseEventCount += observedFlush.pauseEvents.count
        voiceEventCount += observedFlush.voiceEvents.count
        #expect(pauseEventCount > 0)
        #expect(voiceEventCount > 0)
        #expect(VADBenchmarkStrategy.webrtcStable.metadata.classifier == "libfvad+energy-rescue")
    }

    private static func frames() -> [ProcessedAudioFrame] {
        let amplitudes =
            Array(repeating: Float(0), count: 5)
            + Array(repeating: Float(0.12), count: 50)
            + Array(repeating: Float(0), count: 60)
            + Array(repeating: Float(0.12), count: 25)
        return amplitudes.enumerated().map { index, amplitude in
            ProcessedAudioFrame(
                samples: waveform(amplitude: amplitude, frameIndex: index),
                sampleRate: 16_000,
                timestamp: .milliseconds(index * 20)
            )
        }
    }

    private static func waveform(amplitude: Float, frameIndex: Int) -> [Float] {
        (0..<320).map { offset in
            guard amplitude > 0 else { return 0 }
            let sample = frameIndex * 320 + offset
            return amplitude * Float(sin(2 * Double.pi * 220 * Double(sample) / 16_000))
        }
    }

    private static func signatures(_ events: [VoiceActivityEvent]) -> [SelectedVoiceSignature] {
        events.map { event in
            switch event {
            case .speechStarted(let sequence, let timestamp):
                return .started(sequence: sequence, timestamp: timestamp)
            case .speechEnded(let segment):
                return .ended(
                    sequence: segment.sequenceNumber,
                    pcmSHA256: pcmDigest(segment.samples),
                    sampleCount: segment.samples.count,
                    sampleRate: segment.sampleRate,
                    startedAt: segment.startedAt,
                    endedAt: segment.endedAt,
                    reason: segment.endReason
                )
            }
        }
    }

    private static func pcmDigest(_ samples: [Float]) -> String {
        var hasher = SHA256()
        for sample in samples {
            var bits = sample.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { hasher.update(bufferPointer: $0) }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private enum SelectedVoiceSignature: Equatable {
    case started(sequence: UInt64, timestamp: Duration)
    case ended(
        sequence: UInt64,
        pcmSHA256: String,
        sampleCount: Int,
        sampleRate: Double,
        startedAt: Duration,
        endedAt: Duration,
        reason: SpeechSegmentEndReason
    )
}
