import AudioProcessingAPI
import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct TimestampContinuityTests {
    @Test func acceptsEquivalentSampleClockWithAttosecondDrift() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        for index in 0..<7 {
            _ = try await detector.process(
                VADTestSupport.frame(
                    amplitude: 0,
                    milliseconds: 20,
                    timestamp: .milliseconds(index * 20)
                )
            )
        }

        let sampleClockTimestamp = Duration.seconds(Double(7) / 50)
        _ = try await detector.process(
            VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: sampleClockTimestamp
            )
        )
    }

    @Test func rejectsOverlappingAndGappedTimestamps() async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0, milliseconds: 20, timestamp: .zero)
        )
        let overlap = VADTestSupport.frame(
            amplitude: 0,
            milliseconds: 20,
            timestamp: .zero
        )
        await expectDiscontinuity(detector, frame: overlap, expected: .milliseconds(20))

        let gap = VADTestSupport.frame(
            amplitude: 0,
            milliseconds: 20,
            timestamp: .milliseconds(40)
        )
        await expectDiscontinuity(detector, frame: gap, expected: .milliseconds(20))
    }

    @Test(arguments: [-63, 63])
    func rejectsAtLeastOneSampleOfTimestampDiscontinuity(
        offsetMicroseconds: Int
    ) async throws {
        let detector = try AdaptiveEnergyVoiceActivityDetector()
        _ = try await detector.process(
            VADTestSupport.frame(amplitude: 0, milliseconds: 20, timestamp: .zero)
        )
        let timestamp =
            Duration.milliseconds(20)
            + .microseconds(offsetMicroseconds)
        await expectDiscontinuity(
            detector,
            frame: VADTestSupport.frame(
                amplitude: 0,
                milliseconds: 20,
                timestamp: timestamp
            ),
            expected: .milliseconds(20)
        )
    }

    private func expectDiscontinuity(
        _ detector: AdaptiveEnergyVoiceActivityDetector,
        frame: ProcessedAudioFrame,
        expected: Duration
    ) async {
        do {
            _ = try await detector.process(frame)
            Issue.record("Expected timestamp discontinuity")
        } catch let error as VoiceActivityError {
            #expect(
                error
                    == .discontinuousTimestamp(
                        expected: expected,
                        current: frame.timestamp
                    )
            )
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
