import AudioCaptureAPI
import AudioProcessingAPI
@testable import AudioProcessingCore
import Testing

@MainActor
@Suite struct AudioProcessingValidationTests {
    @Test func rejectsMalformedInterleavedSamples() async throws {
        let processor = try MonoResamplingAudioProcessor()
        let malformed = AudioFrame(
            samples: [0, 1, 0],
            sampleRate: 48_000,
            channelCount: 2,
            timestamp: .zero
        )

        do {
            _ = try await processor.process(malformed)
            Issue.record("Expected malformed samples to fail.")
        } catch let error as AudioProcessingError {
            #expect(
                error
                    == .malformedInterleavedSamples(sampleCount: 3, channelCount: 2)
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsNonFiniteSamples() async throws {
        let processor = try MonoResamplingAudioProcessor()
        let malformed = AudioFrame(
            samples: [0, .infinity],
            sampleRate: 16_000,
            channelCount: 1,
            timestamp: .zero
        )

        do {
            _ = try await processor.process(malformed)
            Issue.record("Expected a non-finite sample to fail.")
        } catch let error as AudioProcessingError {
            #expect(error == .nonFiniteSample(index: 1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsInvalidConfiguration() {
        do {
            _ = try MonoResamplingAudioProcessor(
                configuration: .init(targetSampleRate: 0)
            )
            Issue.record("Expected invalid target sample rate")
        } catch let error as AudioProcessingError {
            #expect(error == .invalidTargetSampleRate(0))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
