import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct CandidatePauseTraceTests {
    @Test func thresholdsPreserveOrderPreRollClockAndOvershoot() async throws {
        let detector = try CandidatePauseTestSupport.detector(
            preRoll: .milliseconds(240)
        )
        _ = try await CandidatePauseTestSupport.observe(
            detector,
            amplitude: 0,
            milliseconds: 200,
            timestamp: .seconds(10)
        )
        _ = try await CandidatePauseTestSupport.observe(
            detector,
            amplitude: 0.1,
            milliseconds: 300,
            timestamp: .milliseconds(10_200)
        )
        let pause = try await CandidatePauseTestSupport.observe(
            detector,
            amplitude: 0,
            milliseconds: 420,
            timestamp: .milliseconds(10_500)
        )

        let reached = CandidatePauseTestSupport.reached(in: pause.pauseEvents)
        #expect(reached.map(\.checkpoint.threshold) == CandidatePauseThreshold.allCases)
        #expect(reached.map(\.checkpoint.thresholdSampleCount) == [4_000, 4_800, 6_400])
        #expect(reached.map(\.candidateEnd.sourceSample) == [12_000, 12_800, 14_400])
        let first = try #require(reached.first)
        #expect(first.candidateEnd.timestamp == .milliseconds(10_750))
        #expect(first.currentWindow.startSourceSample == 11_840)
        #expect(first.currentWindow.end.sourceSample == 12_160)
        #expect(first.overshootSampleCount == 160)
    }

    @Test func oneBlipKeepsEpisodeAndTwoSpeechFramesResolveIt() async throws {
        let detector = try CandidatePauseTestSupport.detector()
        let values = try await CandidatePauseTestSupport.pauseLifecycle(detector)

        #expect(CandidatePauseTestSupport.resolved(in: values.blip.pauseEvents).isEmpty)
        let firstReach = try #require(
            CandidatePauseTestSupport.reached(in: values.firstPause.pauseEvents).first
        )
        let nextReach = try #require(
            CandidatePauseTestSupport.reached(in: values.continuedPause.pauseEvents).first
        )
        #expect(firstReach.episode.episodeNumber == 1)
        #expect(nextReach.episode == firstReach.episode)
        let resolution = try #require(
            CandidatePauseTestSupport.resolved(in: values.resumed.pauseEvents).first
        )
        #expect(resolution.episode == firstReach.episode)
        #expect(resolution.reason == .speechResumed)
        let independent = try #require(
            CandidatePauseTestSupport.reached(in: values.secondPause.pauseEvents).first
        )
        #expect(independent.episode.episodeNumber == 2)
    }

    @Test func partialFlushExcludesSyntheticPadding() async throws {
        let detector = try CandidatePauseTestSupport.detector()
        _ = try await CandidatePauseTestSupport.observe(
            detector, amplitude: 0.1, milliseconds: 300, timestamp: .zero
        )
        let complete = try await CandidatePauseTestSupport.observe(
            detector, amplitude: 0, milliseconds: 255, timestamp: .milliseconds(300)
        )
        let flushed = await detector.flushWithShadowEvidence()

        #expect(complete.pauseEvents.isEmpty)
        let reached = try #require(
            CandidatePauseTestSupport.reached(in: flushed.pauseEvents).first
        )
        #expect(reached.candidateEnd.sourceSample == 8_800)
        #expect(reached.currentWindow.startSourceSample == 8_640)
        #expect(reached.currentWindow.end.sourceSample == 8_880)
        #expect(reached.overshootSampleCount == 80)
        let resolved = try #require(
            CandidatePauseTestSupport.resolved(in: flushed.pauseEvents).first
        )
        #expect(resolved.observedAt.sourceSample == 8_880)
        #expect(resolved.reason == .segmentEnded(.endOfStream))
    }
}
