import AudioProcessingAPI
import VADAPI

enum ProcessedAudioFrameValidator {
    private static let sampleRateTolerance = 0.5

    static func validate(
        _ frame: ProcessedAudioFrame,
        requiredSampleRate: Double,
        previousTimestamp: Duration?
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
    }
}
