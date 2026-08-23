import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct MaximumBoundaryTests {
    @Test func preferredMaximumWaitsForStableAcousticBoundary() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        let speech = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 15_000, timestamp: .zero)
        )
        let earlyPause = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 40,
                timestamp: .seconds(15)
            )
        )
        let boundary = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .milliseconds(15_040)
            )
        )

        #expect(VADTestSupport.endedSegments(in: speech + earlyPause).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .maximumBoundary)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 15_060))
    }

    @Test func preferredBoundaryCanRequireLongerPauseForReplayComparison() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: .init(preferredBoundarySilence: .milliseconds(500))
        )
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 15_000, timestamp: .zero)
        )
        let early = try await detector.process(
            VADTestSupport.frame(amplitude: 0, milliseconds: 480, timestamp: .seconds(15))
        )
        let boundary = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .milliseconds(15_480)
            )
        )

        #expect(VADTestSupport.endedSegments(in: early).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .maximumBoundary)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 15_280))
    }
}

extension MaximumBoundaryTests {
    @Test func absoluteCapIs16500MillisecondsAndStartsContinuation() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 15_000, timestamp: .zero)
        )
        let beforeCap = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 1_480,
                timestamp: .seconds(15)
            )
        )
        events += beforeCap
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 260,
                timestamp: .milliseconds(16_480)
            )
        )
        let flushed = await detector.flush()

        #expect(VADTestSupport.endedSegments(in: beforeCap).isEmpty)
        let hardSegment = try #require(VADTestSupport.endedSegments(in: events).first)
        #expect(hardSegment.endReason == .maximumDuration)
        #expect(hardSegment.samples.count == VADTestSupport.sampleCount(milliseconds: 16_500))
        #expect(hardSegment.samples.last == 0.1)
        #expect(VADTestSupport.startedEvents(in: events).map(\.sequenceNumber) == [1, 2])
        let continuation = try #require(VADTestSupport.endedSegments(in: flushed).first)
        #expect(continuation.sequenceNumber == 2)
        #expect(continuation.samples.count == VADTestSupport.sampleCount(milliseconds: 240))
    }

    @Test func confirmedContinuationShorterThanMinimumVoicedIsNotLost() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 16_500, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 100,
                timestamp: .milliseconds(16_500)
            )
        )
        let flushed = await detector.flush()

        let hardSegment = try #require(VADTestSupport.endedSegments(in: events).first)
        #expect(hardSegment.endReason == .maximumDuration)
        #expect(VADTestSupport.startedEvents(in: events).map(\.sequenceNumber) == [1, 2])
        let continuation = try #require(VADTestSupport.endedSegments(in: flushed).first)
        #expect(continuation.sequenceNumber == 2)
        #expect(continuation.samples.count == VADTestSupport.sampleCount(milliseconds: 100))
    }

    @Test func rejectedHardCapCandidateCannotCreateConfirmedContinuation() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: .init(
                shortUtterance: .seconds(20),
                minimumVoiced: .seconds(20)
            )
        )
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 16_500, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 20,
                timestamp: .milliseconds(16_500)
            )
        )
        events += await detector.flush()

        #expect(VADTestSupport.startedEvents(in: events).isEmpty)
        #expect(VADTestSupport.endedSegments(in: events).isEmpty)
    }

    @Test func twoHardCapsPreserveLifecycleSequenceAndEverySample() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 33_100, timestamp: .zero)
        )
        events += await detector.flush()

        let starts = VADTestSupport.startedEvents(in: events).map(\.sequenceNumber)
        let segments = VADTestSupport.endedSegments(in: events)
        #expect(starts == [1, 2, 3])
        #expect(segments.map(\.sequenceNumber) == [1, 2, 3])
        #expect(
            segments.map(\.endReason)
                == [.maximumDuration, .maximumDuration, .endOfStream]
        )
        #expect(
            segments.reduce(0) { $0 + $1.samples.count }
                == VADTestSupport.sampleCount(milliseconds: 33_100)
        )
    }
}
