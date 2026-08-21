import AudioCaptureAPI
@testable import AudioProcessingCore
import Testing

@MainActor
@Suite struct MonoResamplingAudioProcessorTests {
    @Test func downmixesStereoAndResamplesToSixteenKilohertz() async throws {
        let processor = try MonoResamplingAudioProcessor()
        let stereo = Array(repeating: [Float(0.8), Float(0.2)], count: 480)
            .flatMap { $0 }
        let input = AudioFrame(
            samples: stereo,
            sampleRate: 48_000,
            channelCount: 2,
            timestamp: .seconds(2)
        )

        let output = try await processor.process(input)

        #expect(output.sampleRate == 16_000)
        #expect(output.samples.count == 160)
        #expect(output.timestamp == .seconds(2))
        #expect(output.samples.allSatisfy { abs($0 - 0.5) < 0.000_01 })
    }

    @Test func keepsResamplingPhaseAcrossFrames() async throws {
        let streaming = try MonoResamplingAudioProcessor()
        let first = try await streaming.process(frame([0, 1], timestamp: .zero))
        let second = try await streaming.process(
            frame([0, -1], timestamp: .microseconds(250))
        )
        let oneShot = try MonoResamplingAudioProcessor()
        let combined = try await oneShot.process(frame([0, 1, 0, -1], timestamp: .zero))

        assertSamplesEqual(first.samples + second.samples, combined.samples)
        #expect(second.timestamp == .microseconds(125))
    }

    @Test func resetCreatesNewTimestampBoundary() async throws {
        let processor = try MonoResamplingAudioProcessor()
        _ = try await processor.process(frame([0, 1], timestamp: .seconds(1)))

        await processor.reset()
        let output = try await processor.process(frame([1, 0], timestamp: .seconds(8)))

        #expect(output.timestamp == .seconds(8))
    }

    @Test func clampsMonoSamplesWithoutChangingTheirCount() async throws {
        let processor = try MonoResamplingAudioProcessor()
        let input = AudioFrame(
            samples: [-2, -0.5, 0.5, 2],
            sampleRate: 16_000,
            channelCount: 1,
            timestamp: .zero
        )

        let output = try await processor.process(input)

        #expect(output.samples == [-1, -0.5, 0.5, 1])
    }

    private func frame(_ samples: [Float], timestamp: Duration) -> AudioFrame {
        AudioFrame(
            samples: samples,
            sampleRate: 8_000,
            channelCount: 1,
            timestamp: timestamp
        )
    }

    private func assertSamplesEqual(
        _ first: [Float],
        _ second: [Float]
    ) {
        #expect(first.count == second.count)
        for (left, right) in zip(first, second) {
            #expect(abs(left - right) <= 0.000_01)
        }
    }
}
