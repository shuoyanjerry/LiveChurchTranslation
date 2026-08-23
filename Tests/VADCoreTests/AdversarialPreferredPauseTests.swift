import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct AdversarialPreferredPauseTests {
    @Test func recoveredTwoFrameWordCancelsPreferredPauseCandidate() async throws {
        let detector = try detector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 15_000, timestamp: .zero)
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0, milliseconds: 480, timestamp: .seconds(15))
        )
        _ = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 40,
                timestamp: .milliseconds(15_480)
            )
        )
        let secondPause = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 480,
                timestamp: .milliseconds(15_520)
            )
        )
        let boundary = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .seconds(16)
            )
        )

        #expect(VADTestSupport.endedSegments(in: secondPause).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .maximumBoundary)
        let wordStart = VADTestSupport.sampleCount(milliseconds: 15_480)
        let wordEnd = VADTestSupport.sampleCount(milliseconds: 15_520)
        #expect(segment.samples[wordStart..<wordEnd].allSatisfy { $0 == 0.1 })
    }

    @Test func isolatedNoiseFrameDoesNotExtendPreferredPause() async throws {
        let detector = try detector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 15_000, timestamp: .zero)
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0, milliseconds: 480, timestamp: .seconds(15))
        )
        let noise = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 20,
                timestamp: .milliseconds(15_480)
            )
        )
        let boundary = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .milliseconds(15_500)
            )
        )

        #expect(VADTestSupport.endedSegments(in: noise).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .maximumBoundary)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 15_520))
    }

    private func detector() throws -> AdaptiveEnergyVoiceActivityDetector {
        try AdaptiveEnergyVoiceActivityDetector(
            configuration: .init(
                speechStart: .milliseconds(20),
                softSplitAfter: .seconds(20),
                preferredBoundarySilence: .milliseconds(500),
                minimumVoiced: .milliseconds(20),
                decisionWindowCount: 1,
                decisionSpeechVotes: 1
            )
        )
    }
}
