import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct EndpointPauseTests {
    @Test func isolatedRawSpeechFrameDoesNotCancelPause() async throws {
        let detector = try endpointDetector()
        _ = try await process(detector, amplitude: 0.1, milliseconds: 1_000, at: .zero)
        _ = try await process(detector, amplitude: 0, milliseconds: 640, at: .seconds(1))
        let noise = try await process(
            detector, amplitude: 0.1, milliseconds: 20, at: .milliseconds(1_640))
        let boundary = try await process(
            detector, amplitude: 0, milliseconds: 20, at: .milliseconds(1_660))

        #expect(VADTestSupport.endedSegments(in: noise).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .trailingSilence)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 1_680))
    }

    @Test func twoRawSpeechFramesCancelPauseAndRecoveredWordIsRetained() async throws {
        let detector = try endpointDetector()
        var events = try await process(
            detector, amplitude: 0.1, milliseconds: 1_000, at: .zero)
        events += try await process(
            detector, amplitude: 0, milliseconds: 640, at: .seconds(1))
        events += try await process(
            detector, amplitude: 0.1, milliseconds: 40, at: .milliseconds(1_640))
        let afterRecovery = try await process(
            detector, amplitude: 0, milliseconds: 640, at: .milliseconds(1_680))
        let boundary = try await process(
            detector, amplitude: 0, milliseconds: 20, at: .milliseconds(2_320))

        #expect(VADTestSupport.endedSegments(in: events + afterRecovery).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 1_960))
        let wordStart = VADTestSupport.sampleCount(milliseconds: 1_640)
        let wordEnd = VADTestSupport.sampleCount(milliseconds: 1_680)
        #expect(segment.samples[wordStart..<wordEnd].allSatisfy { $0 == 0.1 })
    }

    private func process(
        _ detector: AdaptiveEnergyVoiceActivityDetector,
        amplitude: Float,
        milliseconds: Int,
        at timestamp: Duration
    ) async throws -> [VoiceActivityEvent] {
        try await detector.process(
            VADTestSupport.frame(
                amplitude: amplitude,
                milliseconds: milliseconds,
                timestamp: timestamp
            )
        )
    }

    private func endpointDetector() throws -> AdaptiveEnergyVoiceActivityDetector {
        try AdaptiveEnergyVoiceActivityDetector(
            configuration: VoiceActivityConfiguration(
                shortUtterance: .milliseconds(240),
                shortTrailingSilence: .milliseconds(650)
            )
        )
    }
}
