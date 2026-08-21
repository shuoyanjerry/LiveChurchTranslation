import AVFoundation
import AudioCaptureAPI

enum AudioCaptureTap {
    static func install(
        on inputNode: AVAudioInputNode,
        capacity: AVAudioFrameCount,
        into stream: AsyncThrowingStream<AudioFrame, any Error>.Continuation
    ) {
        inputNode.installTap(
            onBus: 0,
            bufferSize: capacity,
            format: inputNode.outputFormat(forBus: 0)
        ) { buffer, time in
            do {
                let frame = try AudioFrameConverter.convert(buffer, capturedAt: time)
                if case .dropped = stream.yield(frame) {
                    stream.finish(throwing: AudioCaptureError.streamBufferOverflow)
                }
            } catch {
                stream.finish(throwing: error)
            }
        }
    }
}
