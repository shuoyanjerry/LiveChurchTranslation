import AudioProcessingAPI
import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct VoiceActivityValidationTests {
    @Test func rejectsUnexpectedSampleRate() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        let frame = ProcessedAudioFrame(
            samples: [0],
            sampleRate: 48_000,
            timestamp: .zero
        )

        do {
            _ = try await detector.process(frame)
            Issue.record("Expected the sample rate to be rejected.")
        } catch let error as VoiceActivityError {
            #expect(error == .unexpectedSampleRate(expected: 16_000, actual: 48_000))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsBackwardsTimestampsUntilReset() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0, milliseconds: 20, timestamp: .seconds(2))
        )
        let earlier = VADTestSupport.frame(
            amplitude: 0,
            milliseconds: 20,
            timestamp: .seconds(1)
        )

        do {
            _ = try await detector.process(earlier)
            Issue.record("Expected backwards time to be rejected.")
        } catch let error as VoiceActivityError {
            #expect(
                error
                    == .nonMonotonicTimestamp(
                        previous: .seconds(2),
                        current: .seconds(1)
                    )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        await detector.reset()
        _ = try await detector.process(earlier)
    }

    @Test func rejectsInvalidConfiguration() {
        do {
            _ = try AdaptiveEnergyVoiceActivityDetector(
                configuration: .init(trailingSilence: .zero)
            )
            Issue.record("Expected invalid trailing silence")
        } catch let error as VoiceActivityError {
            #expect(error == .invalidConfiguration(parameter: "trailingSilence"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsPreferredMaximumShorterThanPreRoll() {
        do {
            _ = try AdaptiveEnergyVoiceActivityDetector(
                configuration: .init(preferredMaximumSegment: .milliseconds(200))
            )
            Issue.record("Expected invalid preferred maximum")
        } catch let error as VoiceActivityError {
            #expect(
                error
                    == .invalidConfiguration(
                        parameter: "preferredMaximumSegment"
                    )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsNegativeMaximumBoundaryGrace() {
        do {
            _ = try AdaptiveEnergyVoiceActivityDetector(
                configuration: .init(maximumBoundaryGrace: .milliseconds(-1))
            )
            Issue.record("Expected invalid maximum boundary grace")
        } catch let error as VoiceActivityError {
            #expect(error == .invalidConfiguration(parameter: "maximumBoundaryGrace"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsNegativePreferredBoundarySilence() {
        #expect(
            throws: VoiceActivityError.invalidConfiguration(
                parameter: "preferredBoundarySilence"
            )
        ) {
            try AdaptiveEnergyVoiceActivityDetector(
                configuration: .init(preferredBoundarySilence: .milliseconds(-1))
            )
        }
    }

    @Test func rejectsShortHoldBelowMinimumVoiced() {
        #expect(
            throws: VoiceActivityError.invalidConfiguration(
                parameter: "shortUtterance"
            )
        ) {
            try AdaptiveEnergyVoiceActivityDetector(
                configuration: .init(shortUtterance: .milliseconds(100))
            )
        }
    }

    @Test func rejectsShortPauseBelowOrdinaryPause() {
        #expect(
            throws: VoiceActivityError.invalidConfiguration(
                parameter: "shortTrailingSilence"
            )
        ) {
            try AdaptiveEnergyVoiceActivityDetector(
                configuration: .init(shortTrailingSilence: .milliseconds(500))
            )
        }
    }
}
