import Foundation
import RecordingAPI
import SessionManagementAPI

extension LiveSessionCoordinator {
    func acceptsFrames(for sessionID: UUID) -> Bool {
        state.sessionID == sessionID
    }

    func performStop(sessionID: UUID) async {
        let captureStartup = captureStartupTask
        let preparation = preparationTask
        await dependencies.capture.stopCapture()
        _ = await captureStartup?.result
        captureStartupTask = nil
        _ = await preparation?.result
        preparationTask = nil

        let capture = captureTask
        await capture?.value
        captureTask = nil
        await finalizeRecording(sessionID: sessionID)
        for event in await dependencies.vad.flush() {
            await handle(event, sessionID: sessionID)
        }
        if !inferenceIsReady {
            deferQueuedRecordsUntilNextSession()
        }
        await workerTask?.value
        await finishSession(sessionID: sessionID)
    }

    private func finalizeRecording(sessionID: UUID) async {
        guard didStartCapture else {
            try? await dependencies.recordingStore.discard(sessionID: sessionID)
            return
        }
        do {
            _ = try await dependencies.recordingStore.finish(sessionID: sessionID)
        } catch RecordingStoreError.noAudio {
            try? await dependencies.recordingStore.discard(sessionID: sessionID)
        } catch {
            await preserveInterruptedRecording(sessionID: sessionID, after: error)
        }
    }

    private func preserveInterruptedRecording(sessionID: UUID, after error: any Error) async {
        let originalMessage = error.localizedDescription
        do {
            if try await dependencies.recordingStore.repairInterruptedRecording(
                sessionID: sessionID
            ) != nil {
                recordIssue(
                    stage: .finalization,
                    message: "会议录音在保存中断后已恢复。" + originalMessage,
                    isRecoverable: true
                )
                return
            }
            let message =
                "会议录音无法自动完成保存，已保留可恢复的部分录音。"
                + originalMessage
            hasUnrecoverableSessionFailure = true
            terminalFailureMessage = terminalFailureMessage ?? message
            recordIssue(stage: .finalization, message: message, isRecoverable: true)
        } catch {
            hasUnrecoverableSessionFailure = true
            let message =
                "会议录音仍处于可恢复的未完成状态。" + originalMessage
                + "恢复操作还报告：" + error.localizedDescription
            terminalFailureMessage = terminalFailureMessage ?? message
            recordIssue(stage: .finalization, message: message, isRecoverable: true)
        }
    }

    func finishSession(sessionID: UUID) async {
        let failure = terminalFailureMessage
        let result =
            if let failure {
                await sessionFinalizer.fail(
                    failure,
                    hasUnrecoverableFailure: hasUnrecoverableSessionFailure
                )
            } else {
                await sessionFinalizer.finish(
                    sessionID: sessionID,
                    hasUnrecoverableFailure: hasUnrecoverableSessionFailure
                )
            }
        let completion = completion(from: result, sessionID: sessionID)
        segmentQueue.removeAll()
        if let failure {
            state.fail(failure, outcome: completion.outcome)
        } else {
            state.finish(outcome: completion.outcome, message: completion.message)
        }
        modelTask?.cancel()
        modelTask = nil
        inferenceIsReady = false
        captureEndedBeforeInference = false
        if let error = completion.errorMessage {
            publish(.recoverableError(error))
        }
        publishState()
        stopTask = nil
    }

    func requestFailure(_ message: String, stage: LiveSessionIssueStage) async {
        if didStartCapture {
            hasUnrecoverableSessionFailure = true
        }
        terminalFailureMessage = message
        recordIssue(stage: stage, message: message, isRecoverable: true)
        await stop()
    }

    func recordIssue(
        stage: LiveSessionIssueStage,
        message: String,
        isRecoverable: Bool
    ) {
        state.record(
            LiveSessionIssue(
                stage: stage,
                message: message,
                isRecoverable: isRecoverable
            )
        )
        publishState()
        publish(.recoverableError(message))
    }

}
