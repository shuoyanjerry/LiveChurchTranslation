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
            switch processingPolicy {
            case .boundedLive:
                try await consumeConcurrently(stream, sessionID: sessionID)
            case .completeImport:
                try await consumeImportWithBackpressure(stream, sessionID: sessionID)
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

    func handle(_ event: VoiceActivityEvent, sessionID: UUID) async {
        guard state.sessionID == sessionID else { return }
        switch event {
        case .speechStarted:
            if isActive, inferenceIsReady {
                state.transition(
                    to: .listening,
                    message: captureStatusMessage(normal: "已检测到语音")
                )
                publishState()
            }
        case .speechEnded(let segment):
            guard diskRecoveryMode != .recoveryStoreFailure else {
                incrementUnresolvedUtteranceCount()
                return
            }
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
                    message: captureStatusMessage(normal: "正在聆听")
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
            hasUnrecoverableSessionFailure = true
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
        "音频导入在完整听抄前中断，请重新处理原始文件。"
    }
}
