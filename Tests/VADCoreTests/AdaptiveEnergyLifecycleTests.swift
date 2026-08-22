import VADAPI
@testable import VADCore
import Testing

@MainActor
@Suite struct AdaptiveEnergyLifecycleTests {
    @Test func maximumDurationSplitsContinuousSpeech() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: shortConfiguration(maximumSegment: .milliseconds(100))
        )

        let events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 200, timestamp: .zero)
        )

        let started = VADTestSupport.startedEvents(in: events)
        let ended = VADTestSupport.endedSegments(in: events)
        #expect(started.map(\.sequenceNumber) == [1, 2])
        #expect(ended.map(\.endReason) == [.maximumDuration, .maximumDuration])
        #expect(
            ended.allSatisfy {
                $0.samples.count == VADTestSupport.sampleCount(milliseconds: 100)
            })
    }

    @Test func flushClosesActiveSpeechAndAcceptsANewStream() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: shortConfiguration(maximumSegment: .seconds(1))
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
            configuration: shortConfiguration(maximumSegment: .seconds(1))
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

    private func shortConfiguration(
        maximumSegment: Duration
    ) -> VoiceActivityConfiguration {
        VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: .milliseconds(40),
            speechStart: .milliseconds(40),
            trailingSilence: .milliseconds(80),
            softSplitSilence: .milliseconds(40),
            softSplitAfter: .seconds(14),
            maximumSegment: maximumSegment,
            postRoll: .milliseconds(40),
            minimumVoiced: .milliseconds(40),
            decisionWindowCount: 1,
            decisionSpeechVotes: 1
        )
    }
}
