import AudioProcessingAPI
import VADAPI

enum ProcessedAudioFrameValidator {
    private static let sampleRateTolerance = 0.5
    // Duration arithmetic can differ by a few attoseconds when the same audio
    // position is derived through accumulated frames versus a sample counter.
    // One nanosecond is far below a single 16 kHz sample (62.5 microseconds).
    private static let timestampTolerance = Duration.nanoseconds(1)

    static func validate(
        _ frame: ProcessedAudioFrame,
        requiredSampleRate: Double,
        previousTimestamp: Duration?,
        expectedTimestamp: Duration?
    ) throws {
        guard abs(frame.sampleRate - requiredSampleRate) <= sampleRateTolerance else {
            throw VoiceActivityError.unexpectedSampleRate(
                expected: requiredSampleRate,
                actual: frame.sampleRate
            )
        }
        if let index = frame.samples.firstIndex(where: { !$0.isFinite }) {
            throw VoiceActivityError.nonFiniteSample(index: index)
        }
        if let previousTimestamp, frame.timestamp < previousTimestamp {
            throw VoiceActivityError.nonMonotonicTimestamp(
                previous: previousTimestamp,
                current: frame.timestamp
            )
        }
        if let expectedTimestamp {
            let difference = absoluteDifference(frame.timestamp, expectedTimestamp)
            if difference > timestampTolerance {
                throw VoiceActivityError.discontinuousTimestamp(
                    expected: expectedTimestamp,
                    current: frame.timestamp
                )
            }
        }
    }

    private static func absoluteDifference(
        _ lhs: Duration,
        _ rhs: Duration
    ) -> Duration {
        lhs >= rhs ? lhs - rhs : rhs - lhs
    }
}
