import AVFoundation
import AudioCaptureAPI

enum AudioFrameConverter {
    static func convert(
        _ buffer: AVAudioPCMBuffer,
        capturedAt time: AVAudioTime
    ) throws -> AudioFrame {
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)
        guard channelCount > 0, frameCount > 0 else {
            throw AudioCaptureError.invalidConfiguration("The input produced an empty buffer.")
        }
        guard let channels = buffer.floatChannelData else {
            throw AudioCaptureError.invalidConfiguration("The input is not Float32 PCM.")
        }

        let samples: [Float]
        if buffer.format.isInterleaved {
            samples = Array(
                UnsafeBufferPointer(
                    start: channels[0],
                    count: frameCount * channelCount
                ))
        } else {
            samples = interleave(
                channels: channels,
                channelCount: channelCount,
                frameCount: frameCount
            )
        }
        return AudioFrame(
            samples: samples,
            sampleRate: buffer.format.sampleRate,
            channelCount: channelCount,
            timestamp: timestamp(for: time, sampleRate: buffer.format.sampleRate)
        )
    }

    private static func interleave(
        channels: UnsafePointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        frameCount: Int
    ) -> [Float] {
        var result = [Float]()
        result.reserveCapacity(frameCount * channelCount)
        for frameIndex in 0..<frameCount {
            for channelIndex in 0..<channelCount {
                result.append(channels[channelIndex][frameIndex])
            }
        }
        return result
    }

    private static func timestamp(for time: AVAudioTime, sampleRate: Double) -> Duration {
        let seconds: Double
        if time.isSampleTimeValid, sampleRate > 0 {
            seconds = Double(time.sampleTime) / sampleRate
        } else if time.isHostTimeValid {
            seconds = AVAudioTime.seconds(forHostTime: time.hostTime)
        } else {
            return .zero
        }
        guard seconds.isFinite, seconds >= 0 else { return .zero }
        let nanoseconds = min(seconds * 1_000_000_000, Double(Int64.max))
        return .nanoseconds(Int64(nanoseconds.rounded()))
    }
}
