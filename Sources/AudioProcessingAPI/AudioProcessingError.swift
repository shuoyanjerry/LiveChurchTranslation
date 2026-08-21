/// Failures that prevent an input frame from being converted safely.
public enum AudioProcessingError: Error, Sendable, Equatable {
    case invalidTargetSampleRate(Double)
    case invalidAmplitudeLimit(Float)
    case invalidInputSampleRate(Double)
    case invalidChannelCount(Int)
    case malformedInterleavedSamples(sampleCount: Int, channelCount: Int)
    case nonFiniteSample(index: Int)
}

extension AudioProcessingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidTargetSampleRate(let rate):
            "Target sample rate must be finite and positive; received \(rate)."
        case .invalidAmplitudeLimit(let limit):
            "Amplitude limit must be finite and positive; received \(limit)."
        case .invalidInputSampleRate(let rate):
            "Input sample rate must be finite and positive; received \(rate)."
        case .invalidChannelCount(let count):
            "Channel count must be positive; received \(count)."
        case .malformedInterleavedSamples(let sampleCount, let channelCount):
            "\(sampleCount) samples cannot be divided into \(channelCount) channels."
        case .nonFiniteSample(let index):
            "Input sample at index \(index) is not finite."
        }
    }
}
