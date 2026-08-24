import AudioCaptureAPI

struct AudioFrameFanout: Sendable {
    let recording: AudioFrameStream.Stream
    let processing: AudioFrameStream.Stream

    private let recordingContinuation: AudioFrameStream.Stream.Continuation
    private let processingContinuation: AudioFrameStream.Stream.Continuation

    init(frameLimit: Int = AudioFrameStream.defaultBacklogFrameLimit) {
        let recordingPair = AudioFrameStream.makeBounded(frameLimit: frameLimit)
        let processingPair = AudioFrameStream.makeBounded(frameLimit: frameLimit)
        recording = recordingPair.stream
        processing = processingPair.stream
        recordingContinuation = recordingPair.continuation
        processingContinuation = processingPair.continuation
    }

    func forward(_ source: AudioFrameStream.Stream) async throws {
        do {
            for try await frame in source {
                try Task.checkCancellation()
                try enqueue(frame, into: recordingContinuation, stage: .recording)
                try enqueue(frame, into: processingContinuation, stage: .processing)
            }
            finish()
        } catch {
            finish(throwing: error)
            throw error
        }
    }

    private func enqueue(
        _ frame: AudioFrame,
        into continuation: AudioFrameStream.Stream.Continuation,
        stage: AudioPipelineFailure.Stage
    ) throws {
        guard case .enqueued = continuation.yield(frame) else {
            throw AudioPipelineFailure(
                stage: stage,
                message: "处理速度未能跟上，录音已停止并保留已录内容。"
            )
        }
    }

    private func finish(throwing error: (any Error)? = nil) {
        if let error {
            recordingContinuation.finish(throwing: error)
            processingContinuation.finish(throwing: error)
        } else {
            recordingContinuation.finish()
            processingContinuation.finish()
        }
    }
}
