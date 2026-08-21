import VADAPI
@testable import VADCore
import Testing

@MainActor
@Suite struct AdaptiveEnergySilenceTests {
    @Test func defaultEndsAfterApproximately650MillisecondsOfSilence() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        let speechEvents = try await detector.process(
            VADTestSupport.frame(amplitude: 0.1, milliseconds: 120, timestamp: .zero)
        )
        let earlySilenceEvents = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 640,
                timestamp: .milliseconds(120)
            )
        )
        let boundaryEvents = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: .milliseconds(760)
            )
        )

        #expect(VADTestSupport.startedEvents(in: speechEvents).count == 1)
        #expect(VADTestSupport.endedSegments(in: earlySilenceEvents).isEmpty)
        let ended = VADTestSupport.endedSegments(in: boundaryEvents)
        #expect(ended.count == 1)
        #expect(ended.first?.endReason == .trailingSilence)
    }

    @Test func adaptiveNoiseFloorRejectsSteadyBackgroundEnergy() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector(
            configuration: testConfiguration(
                minimumSpeechRMS: 0.005,
                thresholdMultiplier: 2
            )
        )
        var events: [VoiceActivityEvent] = []
        for index in 0..<10 {
            events += try await detector.process(
                VADTestSupport.frame(
                    amplitude: 0.004,
                    milliseconds: 20,
                    timestamp: .milliseconds(index * 20)
                )
            )
        }
        events += try await detector.process(
            VADTestSupport.frame(
                amplitude: 0.006,
                milliseconds: 60,
                timestamp: .milliseconds(200)
            )
        )

        #expect(VADTestSupport.startedEvents(in: events).isEmpty)
    }

    private func testConfiguration(
        minimumSpeechRMS: Float,
        thresholdMultiplier: Float
    ) -> VoiceActivityConfiguration {
        VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: .milliseconds(40),
            speechStart: .milliseconds(40),
            trailingSilence: .milliseconds(80),
            maximumSegment: .seconds(1),
            initialNoiseFloorRMS: 0.001,
            minimumSpeechRMS: minimumSpeechRMS,
            speechThresholdMultiplier: thresholdMultiplier,
            noiseFloorSmoothing: 0.5
        )
    }
}
