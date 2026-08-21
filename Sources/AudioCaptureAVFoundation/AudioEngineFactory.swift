import AVFoundation
import AudioCaptureAPI

struct PreparedAudioEngine {
    let engine: AVAudioEngine
    let inputNode: AVAudioInputNode
    let capacity: AVAudioFrameCount
}

enum AudioEngineFactory {
    static func prepare(request: AudioCaptureRequest) throws -> PreparedAudioEngine {
        let bufferSeconds = try validatedSeconds(for: request.bufferDuration)
        let selectedInput = try CoreAudioInputDeviceCatalog.resolve(request.deviceID)
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        try AudioInputSelector.select(selectedInput.objectID, on: inputNode)
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw AudioCaptureError.invalidConfiguration("The selected input has no PCM format.")
        }
        return PreparedAudioEngine(
            engine: engine,
            inputNode: inputNode,
            capacity: try frameCapacity(
                durationSeconds: bufferSeconds,
                sampleRate: format.sampleRate
            )
        )
    }

    static func start(
        _ prepared: PreparedAudioEngine,
        stream: AsyncThrowingStream<AudioFrame, any Error>.Continuation
    ) throws {
        prepared.engine.prepare()
        do {
            try prepared.engine.start()
        } catch {
            prepared.inputNode.removeTap(onBus: 0)
            stream.finish(throwing: error)
            throw AudioCaptureError.engineStartFailed(error.localizedDescription)
        }
    }

    private static func validatedSeconds(for duration: Duration) throws -> Double {
        let seconds = duration.audioSeconds
        guard seconds.isFinite, seconds > 0 else {
            throw AudioCaptureError.invalidConfiguration("Buffer duration must be positive.")
        }
        return seconds
    }

    private static func frameCapacity(
        durationSeconds: Double,
        sampleRate: Double
    ) throws -> AVAudioFrameCount {
        let frames = (durationSeconds * sampleRate).rounded(.up)
        guard frames >= 1, frames <= Double(UInt32.max) else {
            throw AudioCaptureError.invalidConfiguration("Buffer duration is out of range.")
        }
        return AVAudioFrameCount(frames)
    }
}
