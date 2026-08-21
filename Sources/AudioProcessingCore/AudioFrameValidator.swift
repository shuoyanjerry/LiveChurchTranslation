import AudioCaptureAPI
import AudioProcessingAPI

enum AudioFrameValidator {
    static func validate(_ frame: AudioFrame) throws {
        guard frame.sampleRate.isFinite, frame.sampleRate > 0 else {
            throw AudioProcessingError.invalidInputSampleRate(frame.sampleRate)
        }
        guard frame.channelCount > 0 else {
            throw AudioProcessingError.invalidChannelCount(frame.channelCount)
        }
        guard frame.samples.count.isMultiple(of: frame.channelCount) else {
            throw AudioProcessingError.malformedInterleavedSamples(
                sampleCount: frame.samples.count,
                channelCount: frame.channelCount
            )
        }
        if let index = frame.samples.firstIndex(where: { !$0.isFinite }) {
            throw AudioProcessingError.nonFiniteSample(index: index)
        }
    }

    static func validate(_ configuration: AudioProcessingConfiguration) throws {
        let rate = configuration.targetSampleRate
        guard rate.isFinite, rate > 0 else {
            throw AudioProcessingError.invalidTargetSampleRate(rate)
        }
        let limit = configuration.amplitudeLimit
        guard limit.isFinite, limit > 0 else {
            throw AudioProcessingError.invalidAmplitudeLimit(limit)
        }
    }
}
