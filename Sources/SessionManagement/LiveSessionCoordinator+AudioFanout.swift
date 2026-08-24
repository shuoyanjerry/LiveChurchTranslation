import AudioCaptureAPI
import Foundation
import VADAPI

extension LiveSessionCoordinator {
    func consumeImportWithBackpressure(
        _ stream: AudioFrameStream.Stream,
        sessionID: UUID
    ) async throws {
        do {
            for try await frame in stream {
                try Task.checkCancellation()
                guard acceptsFrames(for: sessionID) else { break }
                do {
                    try await dependencies.recordingStore.append(frame, to: sessionID)
                } catch {
                    throw AudioPipelineFailure(
                        stage: .recording,
                        message: error.localizedDescription
                    )
                }
                try await processCapturedFrame(frame, sessionID: sessionID)
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let failure as AudioPipelineFailure {
            throw failure
        } catch {
            throw AudioPipelineFailure(stage: .capture, message: error.localizedDescription)
        }
    }

    func consumeConcurrently(
        _ stream: AudioFrameStream.Stream,
        sessionID: UUID
    ) async throws {
        let fanout = AudioFrameFanout()
        var failures: [AudioPipelineFailure] = []
        try await withThrowingTaskGroup(of: Void.self) { group in
            addCaptureTask(to: &group, fanout: fanout, stream: stream)
            addRecordingTask(to: &group, fanout: fanout, sessionID: sessionID)
            addProcessingTask(to: &group, fanout: fanout, sessionID: sessionID)

            while !group.isEmpty {
                do {
                    try await group.next()
                } catch is CancellationError {
                    group.cancelAll()
                    throw CancellationError()
                } catch let failure as AudioPipelineFailure {
                    failures.append(failure)
                    await dependencies.capture.stopCapture()
                }
            }
        }
        if let failure = failures.min(by: { $0.stage.rawValue < $1.stage.rawValue }) {
            throw failure
        }
    }

    private func addCaptureTask(
        to group: inout ThrowingTaskGroup<Void, any Error>,
        fanout: AudioFrameFanout,
        stream: AudioFrameStream.Stream
    ) {
        group.addTask {
            do {
                try await fanout.forward(stream)
            } catch is CancellationError {
                throw CancellationError()
            } catch let failure as AudioPipelineFailure {
                throw failure
            } catch {
                throw AudioPipelineFailure(
                    stage: .capture,
                    message: error.localizedDescription
                )
            }
        }
    }

    private func addRecordingTask(
        to group: inout ThrowingTaskGroup<Void, any Error>,
        fanout: AudioFrameFanout,
        sessionID: UUID
    ) {
        group.addTask { [recordingStore = dependencies.recordingStore] in
            do {
                for try await frame in fanout.recording {
                    do {
                        try await recordingStore.append(frame, to: sessionID)
                    } catch {
                        throw AudioPipelineFailure(
                            stage: .recording,
                            message: error.localizedDescription
                        )
                    }
                }
            } catch let failure as AudioPipelineFailure {
                throw failure
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw AudioPipelineFailure(stage: .capture, message: error.localizedDescription)
            }
        }
    }

    private func addProcessingTask(
        to group: inout ThrowingTaskGroup<Void, any Error>,
        fanout: AudioFrameFanout,
        sessionID: UUID
    ) {
        group.addTask { [weak self] in
            guard let self else { return }
            do {
                for try await frame in fanout.processing {
                    try Task.checkCancellation()
                    guard await self.acceptsFrames(for: sessionID) else { break }
                    try await self.processCapturedFrame(frame, sessionID: sessionID)
                }
            } catch let failure as AudioPipelineFailure {
                throw failure
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw AudioPipelineFailure(stage: .capture, message: error.localizedDescription)
            }
        }
    }

    private func processCapturedFrame(_ frame: AudioFrame, sessionID: UUID) async throws {
        establishSentenceAudioTimeline(with: frame)
        do {
            let processed = try await dependencies.audioProcessor.process(frame)
            let events = try await dependencies.vad.process(processed)
            guard acceptsFrames(for: sessionID) else { return }
            for event in events {
                await handle(event, sessionID: sessionID)
            }
        } catch {
            throw AudioPipelineFailure(stage: .processing, message: error.localizedDescription)
        }
    }

    private func establishSentenceAudioTimeline(with frame: AudioFrame) {
        guard processingPolicy == .boundedLive, sentenceAudioTimelineAnchor == nil else { return }
        sentenceAudioTimelineAnchor = SentenceAudioTimelineAnchor(
            audioTimestamp: audioFrameEnd(frame),
            monotonicTimestamp: sentenceVisibilityClock.now()
        )
    }

    private func audioFrameEnd(_ frame: AudioFrame) -> Duration {
        guard frame.sampleRate.isFinite, frame.sampleRate > 0 else { return frame.timestamp }
        return frame.timestamp + .seconds(Double(frame.frameCount) / frame.sampleRate)
    }
}
