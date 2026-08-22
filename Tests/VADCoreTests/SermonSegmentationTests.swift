import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct SermonSegmentationTests {
    @Test func longUtteranceSoftSplitsAtBriefPause() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: configuration()
        )
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 220, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 60,
                timestamp: .milliseconds(220)
            )
        )

        let segment = try #require(VADTestSupport.endedSegments(in: events).first)
        #expect(segment.endReason == .softSilence)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 260))
    }

    @Test func normalEndTrimsSilenceToPostRoll() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: configuration(softSplitAfter: .seconds(2))
        )
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 100, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 100,
                timestamp: .milliseconds(100)
            )
        )

        let segment = try #require(VADTestSupport.endedSegments(in: events).first)
        #expect(segment.endReason == .trailingSilence)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 140))
    }

    @Test func minimumVoicedDurationRejectsTransientNoise() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: configuration(minimumVoiced: .milliseconds(60))
        )
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 40, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 100,
                timestamp: .milliseconds(40)
            )
        )

        #expect(VADTestSupport.endedSegments(in: events).isEmpty)
    }

    @Test func votingRejectsTwoFrameImpulse() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: configuration(
                minimumVoiced: .milliseconds(40),
                decisionWindowCount: 5,
                decisionSpeechVotes: 3
            )
        )
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 40, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 100,
                timestamp: .milliseconds(40)
            )
        )

        #expect(VADTestSupport.startedEvents(in: events).isEmpty)
    }

    private func configuration(
        softSplitAfter: Duration = .milliseconds(200),
        minimumVoiced: Duration = .milliseconds(40),
        decisionWindowCount: Int = 1,
        decisionSpeechVotes: Int = 1
    ) -> VoiceActivityConfiguration {
        VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: .milliseconds(40),
            speechStart: .milliseconds(40),
            trailingSilence: .milliseconds(100),
            shortUtterance: minimumVoiced,
            shortTrailingSilence: .milliseconds(100),
            softSplitSilence: .milliseconds(60),
            softSplitAfter: softSplitAfter,
            preferredMaximumSegment: .seconds(3),
            maximumBoundaryGrace: .zero,
            postRoll: .milliseconds(40),
            minimumVoiced: minimumVoiced,
            decisionWindowCount: decisionWindowCount,
            decisionSpeechVotes: decisionSpeechVotes
        )
    }
}
