import VADAPI
@testable import VADCore
import Testing

@MainActor
@Suite struct AdaptiveEnergyLifecycleTests {
    @Test func hardMaximumPreservesTailAndContinuesSpeech() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: shortConfiguration(
                preferredMaximumSegment: .milliseconds(100),
                maximumBoundaryGrace: .milliseconds(40)
            )
        )

        let events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 200, timestamp: .zero)
        )
        let flushed = await detector.flush()

        let started = VADTestSupport.startedEvents(in: events)
        let ended = VADTestSupport.endedSegments(in: events)
        #expect(started.map(\.sequenceNumber) == [1, 2])
        #expect(ended.map(\.endReason) == [.maximumDuration])
        #expect(ended.first?.samples.count == VADTestSupport.sampleCount(milliseconds: 140))
        #expect(ended.first?.samples.last == 0.1)
        #expect(VADTestSupport.endedSegments(in: flushed).first?.sequenceNumber == 2)
    }

    @Test func flushClosesActiveSpeechAndAcceptsANewStream() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: shortConfiguration()
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 60, timestamp: .zero)
        )

        let flushed = await detector.flush()
        let nextEvents = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 40, timestamp: .zero)
        )

        #expect(
            VADTestSupport.endedSegments(in: flushed).first?.endReason
                == .endOfStream
        )
        #expect(
            VADTestSupport.startedEvents(in: nextEvents).first?.sequenceNumber
                == 2
        )
    }

    @Test func resetDiscardsSpeechAndRestartsSequenceNumbers() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: shortConfiguration()
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 40, timestamp: .zero)
        )

        await detector.reset()
        let flushed = await detector.flush()
        let nextEvents = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 40, timestamp: .zero)
        )

        #expect(flushed.isEmpty)
        #expect(
            VADTestSupport.startedEvents(in: nextEvents).first?.sequenceNumber
                == 1
        )
    }

    @Test func flushRejectsSpeechBelowMinimumVoicedDuration() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: shortConfiguration(minimumVoiced: .milliseconds(60))
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 40, timestamp: .zero)
        )

        let events = await detector.flush()

        #expect(VADTestSupport.endedSegments(in: events).isEmpty)
    }

    private func shortConfiguration(
        preferredMaximumSegment: Duration = .seconds(1),
        maximumBoundaryGrace: Duration = .milliseconds(40),
        minimumVoiced: Duration = .milliseconds(40)
    ) -> VoiceActivityConfiguration {
        VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: .milliseconds(40),
            speechStart: .milliseconds(40),
            trailingSilence: .milliseconds(80),
            softSplitSilence: .milliseconds(40),
            softSplitAfter: .seconds(14),
            preferredMaximumSegment: preferredMaximumSegment,
            maximumBoundaryGrace: maximumBoundaryGrace,
            postRoll: .milliseconds(40),
            minimumVoiced: minimumVoiced,
            decisionWindowCount: 1,
            decisionSpeechVotes: 1
        )
    }
}
