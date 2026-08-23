import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct MinimumVoicedFlushTests {
    @Test func flushHonorsCalibratedMinimumVoicedDuration() async throws {
        for milliseconds in stride(from: 100, through: 220, by: 20) {
            let shortDetector = try AdaptiveEnergyVoiceActivityDetector()
            var rejected = try await shortDetector.process(
                VADTestSupport.frame(
                    amplitude: 0.1,
                    milliseconds: milliseconds,
                    timestamp: .zero
                )
            )
            rejected += await shortDetector.flush()

            #expect(VADTestSupport.startedEvents(in: rejected).isEmpty)
            #expect(VADTestSupport.endedSegments(in: rejected).isEmpty)
        }

        let exactDetector = try AdaptiveEnergyVoiceActivityDetector()
        var accepted = try await exactDetector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 240, timestamp: .zero)
        )
        accepted += await exactDetector.flush()

        #expect(VADTestSupport.startedEvents(in: accepted).map(\.sequenceNumber) == [1])
        let segment = try #require(VADTestSupport.endedSegments(in: accepted).first)
        #expect(segment.sequenceNumber == 1)
        #expect(segment.endReason == .endOfStream)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 240))
    }

    @Test func trailingSilenceClosesShortCandidateWithoutLifecycleEvents() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        var rejected = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 220, timestamp: .zero)
        )
        rejected += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 1_000,
                timestamp: .milliseconds(220)
            )
        )

        #expect(VADTestSupport.startedEvents(in: rejected).isEmpty)
        #expect(VADTestSupport.endedSegments(in: rejected).isEmpty)

        var accepted = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 240,
                timestamp: .milliseconds(1_220)
            )
        )
        accepted += await detector.flush()

        #expect(VADTestSupport.startedEvents(in: accepted).map(\.sequenceNumber) == [1])
        #expect(VADTestSupport.endedSegments(in: accepted).map(\.sequenceNumber) == [1])
    }
}

extension MinimumVoicedFlushTests {
    @Test func confirmationAndHardBoundaryEmitOrderedLifecyclePair() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: VoiceActivityConfiguration(
                preRoll: .milliseconds(100),
                speechStart: .milliseconds(100),
                shortUtterance: .milliseconds(240),
                preferredMaximumSegment: .milliseconds(240),
                maximumBoundaryGrace: .zero,
                minimumVoiced: .milliseconds(240),
                decisionWindowCount: 1,
                decisionSpeechVotes: 1
            )
        )

        let events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 240, timestamp: .zero)
        )

        guard events.count == 2 else {
            Issue.record("Expected one start and one end event")
            return
        }
        guard case .speechStarted(let sequenceNumber, _) = events[0] else {
            Issue.record("Expected speechStarted before speechEnded")
            return
        }
        #expect(sequenceNumber == 1)
        guard case .speechEnded(let segment) = events[1] else {
            Issue.record("Expected speechEnded after speechStarted")
            return
        }
        #expect(segment.sequenceNumber == sequenceNumber)
        #expect(segment.endReason == .maximumDuration)
    }

    @Test func flushClassifiesPaddedWindowButRetainsOnlyValidSamples() async throws {
        let configuration = VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: .milliseconds(20),
            speechStart: .milliseconds(10),
            trailingSilence: .milliseconds(20),
            shortUtterance: .milliseconds(20),
            shortTrailingSilence: .milliseconds(20),
            softSplitSilence: .milliseconds(20),
            softSplitAfter: .seconds(1),
            preferredMaximumSegment: .seconds(2),
            maximumBoundaryGrace: .zero,
            postRoll: .zero,
            minimumVoiced: .milliseconds(10),
            decisionWindowCount: 1,
            decisionSpeechVotes: 1
        )
        let detector = try CalibratedVoiceActivityDetector(
            classifier: ExactWindowClassifier(),
            configuration: configuration
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 10, timestamp: .zero)
        )

        let events = await detector.flush()
        let segment = try #require(VADTestSupport.endedSegments(in: events).first)
        #expect(segment.samples.count == 160)
        #expect(segment.samples.allSatisfy { $0 == 0.1 })
    }

    @Test func syntheticPaddingCannotSatisfyMinimumVoicedDuration() async throws {
        let configuration = VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: .milliseconds(20),
            speechStart: .milliseconds(20),
            trailingSilence: .milliseconds(20),
            shortUtterance: .milliseconds(20),
            shortTrailingSilence: .milliseconds(20),
            softSplitSilence: .milliseconds(20),
            softSplitAfter: .seconds(1),
            preferredMaximumSegment: .seconds(2),
            maximumBoundaryGrace: .zero,
            postRoll: .zero,
            minimumVoiced: .milliseconds(20),
            decisionWindowCount: 1,
            decisionSpeechVotes: 1
        )
        let detector = try CalibratedVoiceActivityDetector(
            classifier: ExactWindowClassifier(),
            configuration: configuration
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 10, timestamp: .zero)
        )

        let events = await detector.flush()
        #expect(VADTestSupport.startedEvents(in: events).isEmpty)
        #expect(VADTestSupport.endedSegments(in: events).isEmpty)
    }
}

private struct ExactWindowClassifier: VoiceActivityClassifying {
    mutating func isSpeech(_ samples: [Float], whileSpeaking _: Bool) -> Bool {
        #expect(samples.count == 320)
        return samples.contains { $0 != 0 }
    }

    mutating func reset() {}
}
