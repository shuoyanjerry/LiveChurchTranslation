import AudioCaptureAPI
import RecordingAPI

enum RecordingFrameValidator {
    static func validate(_ frame: AudioFrame) throws -> RecordingFormat {
        guard
            frame.sampleRate.isFinite,
            frame.sampleRate >= 1,
            frame.sampleRate <= Double(UInt32.max),
            frame.sampleRate.rounded(.towardZero) == frame.sampleRate,
            let sampleRate = UInt32(exactly: frame.sampleRate)
        else {
            throw RecordingStoreError.invalidSampleRate(frame.sampleRate)
        }
        guard frame.channelCount > 0, frame.channelCount <= Int(UInt32.max) / 2 else {
            throw RecordingStoreError.invalidChannelCount(frame.channelCount)
        }
        let format = RecordingFormat(
            sampleRate: sampleRate,
            channelCount: frame.channelCount
        )
        guard !frame.samples.isEmpty else { throw RecordingStoreError.emptyFrame }
        guard frame.samples.count.isMultiple(of: frame.channelCount) else {
            throw RecordingStoreError.unalignedSamples(
                sampleCount: frame.samples.count,
                channelCount: frame.channelCount
            )
        }
        for (index, sample) in frame.samples.enumerated() {
            guard sample.isFinite else {
                throw RecordingStoreError.nonFiniteSample(index: index)
            }
            guard (-1.0...1.0).contains(sample) else {
                throw RecordingStoreError.sampleOutOfRange(index: index)
            }
        }
        return format
    }
}
