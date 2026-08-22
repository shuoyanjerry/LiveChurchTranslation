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
}
