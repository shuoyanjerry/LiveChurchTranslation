import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct SermonProfileCalibrationTests {
    @Test func sermonDefaultsMatchMeasuredCalibration() {
        let configuration = VoiceActivityConfiguration.sermon

        #expect(configuration.requiredSampleRate == 16_000)
        #expect(configuration.analysisWindow == .milliseconds(20))
        #expect(configuration.preRoll == .milliseconds(240))
        #expect(configuration.trailingSilence == .milliseconds(650))
        #expect(configuration.shortUtterance == .milliseconds(3_500))
        #expect(configuration.shortTrailingSilence == .milliseconds(950))
        #expect(configuration.softSplitSilence == .milliseconds(500))
        #expect(configuration.softSplitAfter == .seconds(9))
        #expect(configuration.preferredMaximumSegment == .seconds(15))
        #expect(configuration.maximumBoundaryGrace == .milliseconds(1_500))
        #expect(configuration.maximumSegment == .seconds(15))
        #expect(configuration.postRoll == .milliseconds(280))
        #expect(configuration.minimumVoiced == .milliseconds(240))
        #expect(configuration.decisionWindowCount == 5)
        #expect(configuration.decisionSpeechVotes == 3)
    }

    @Test func legacyMaximumLabelMapsToPreferredBoundary() {
        let configuration = VoiceActivityConfiguration(
            maximumSegment: .seconds(12)
        )

        #expect(configuration.preferredMaximumSegment == .seconds(12))
        #expect(configuration.maximumBoundaryGrace == .milliseconds(1_500))
    }

    @Test func fiveHundredMillisecondPauseBeforeNineSecondsDoesNotSplit() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 8_980, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 500,
                timestamp: .milliseconds(8_980)
            )
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.1,
                milliseconds: 40,
                timestamp: .milliseconds(9_480)
            )
        )

        #expect(VADTestSupport.endedSegments(in: events).isEmpty)
    }

    @Test func fiveHundredMillisecondPauseAfterNineSecondsSoftSplits() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        var events = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 9_000, timestamp: .zero)
        )
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 500,
                timestamp: .seconds(9)
            )
        )

        let segment = try #require(VADTestSupport.endedSegments(in: events).first)
        #expect(segment.endReason == .softSilence)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 9_280))
    }

    @Test func ordinaryPhraseEndsAtFirstWindowPast650Milliseconds() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 3_600, timestamp: .zero)
        )
        let early = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 640,
                timestamp: .milliseconds(3_600)
            )
        )
        let boundary = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .milliseconds(4_240)
            )
        )

        #expect(VADTestSupport.endedSegments(in: early).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .trailingSilence)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 3_880))
    }

    @Test func shortPhraseWaitsForNineHundredFiftyMilliseconds() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 1_000, timestamp: .zero)
        )
        let early = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 940,
                timestamp: .seconds(1)
            )
        )
        let boundary = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .milliseconds(1_940)
            )
        )

        #expect(VADTestSupport.endedSegments(in: early).isEmpty)
        let segment = try #require(VADTestSupport.endedSegments(in: boundary).first)
        #expect(segment.endReason == .trailingSilence)
        #expect(segment.samples.count == VADTestSupport.sampleCount(milliseconds: 1_280))
    }
}
