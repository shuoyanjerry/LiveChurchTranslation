import AudioCaptureAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

extension LiveSessionCoordinator {
    func consume(
        _ stream: AsyncThrowingStream<AudioFrame, any Error>,
        sessionID: UUID
    ) async {
        do {
            for try await frame in stream {
                guard acceptsFrames(for: sessionID) else { break }
                establishSentenceAudioTimeline(with: frame)
                try await dependencies.recordingStore.append(frame, to: sessionID)
                let events = try await process(frame)
                guard acceptsFrames(for: sessionID) else { break }
                for event in events {
                    await handle(event, sessionID: sessionID)
                }
            }
            captureDidEnd(
                sessionID: sessionID,
                failure: nil,
                sourceWasExhausted: isActive
            )
        } catch is CancellationError {
            captureDidEnd(
                sessionID: sessionID,
                failure: nil,
                sourceWasExhausted: false
            )
        } catch {
            captureDidEnd(
                sessionID: sessionID,
                failure: error.localizedDescription,
                sourceWasExhausted: false
            )
        }
    }

    private func process(_ frame: AudioFrame) async throws -> [VoiceActivityEvent] {
        let processed = try await dependencies.audioProcessor.process(frame)
        return try await dependencies.vad.process(processed)
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

    func handle(_ event: VoiceActivityEvent, sessionID: UUID) async {
        guard state.sessionID == sessionID else { return }
        switch event {
        case .speechStarted:
            if isActive, inferenceIsReady {
                state.transition(
                    to: .listening,
                    message: captureStatusMessage(normal: "Speech detected")
                )
                publishState()
            }
        case .speechEnded(let segment):
            do {
                let record = try await dependencies.recoveryStore.stage(segment, for: sessionID)
                await process(record, sessionID: sessionID)
            } catch {
                preserve(
                    segment,
                    after: UtteranceProcessingFailure(
                        stage: .persistence,
                        message: error.localizedDescription,
                        pendingEntry: nil
                    )
                )
            }
        }
    }

    private func process(
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) async {
        switch processingPolicy {
        case .boundedLive:
            enqueueOrDefer(record, sessionID: sessionID)
        case .completeImport:
            guard inferenceIsReady else {
                enqueueOrDefer(record, sessionID: sessionID)
                return
            }
            guard diskRecoveryMode == nil else {
                deferToDiskRecovery(record)
                return
            }
            await processQueuedRecord(record, sessionID: sessionID)
        }
    }

    func startWorkerIfNeeded(sessionID: UUID) {
        guard inferenceIsReady, workerTask == nil, !segmentQueue.isEmpty else { return }
        workerTask = Task { [weak self] in
            await self?.drainSegments(sessionID: sessionID)
        }
    }

    private func drainSegments(sessionID: UUID) async {
        while let record = segmentQueue.dequeue() {
            await processQueuedRecord(record, sessionID: sessionID)
            if isActive {
                state.transition(
                    to: .listening,
                    message: captureStatusMessage(normal: "Listening")
                )
                publishState()
            }
        }
        workerTask = nil
    }

    private func captureDidEnd(
        sessionID: UUID,
        failure: String?,
        sourceWasExhausted: Bool
    ) {
        guard state.sessionID == sessionID else { return }
        let incompleteImport = processingPolicy.requiresCompleteCapture && !sourceWasExhausted
        if let message = failure ?? (incompleteImport ? incompleteImportMessage : nil) {
            terminalFailureMessage = terminalFailureMessage ?? message
            recordIssue(stage: .audioProcessing, message: message, isRecoverable: true)
            Task { [weak self] in
                await self?.stop()
            }
            return
        }
        guard inferenceIsReady else {
            captureEndedBeforeInference = true
            return
        }
        Task { [weak self] in
            await self?.stop()
        }
    }

    private var incompleteImportMessage: String {
        "Audio import ended before the complete file was transcribed. Retry the original file."
    }
}
