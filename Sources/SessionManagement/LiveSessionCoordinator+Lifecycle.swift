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
        await sessionPreparer.cancel()
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
                    message: "The meeting recording was recovered after an interrupted save. "
                        + originalMessage,
                    isRecoverable: true
                )
                return
            }
            let message =
                "The meeting recording could not be finalized automatically. "
                + "Any partial recording was retained for recovery. " + originalMessage
            terminalFailureMessage = terminalFailureMessage ?? message
            recordIssue(stage: .finalization, message: message, isRecoverable: true)
        } catch {
            let message =
                "The meeting recording remains in recoverable partial form. "
                + originalMessage + " Recovery also reported: " + error.localizedDescription
            terminalFailureMessage = terminalFailureMessage ?? message
            recordIssue(stage: .finalization, message: message, isRecoverable: true)
        }
    }

    func finishSession(sessionID: UUID) async {
        let failure = terminalFailureMessage
        let result =
            if let failure {
                await sessionFinalizer.fail(failure)
            } else {
                await sessionFinalizer.finish(sessionID: sessionID)
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

    private func completion(
        from result: SessionPersistenceResult,
        sessionID: UUID
    ) -> SessionCompletion {
        let unresolved = unresolvedUtteranceCount
        switch result {
        case .failed(let transcript, let message):
            unsavedTranscripts[sessionID] = transcript
            state.record(
                LiveSessionIssue(
                    stage: .finalization,
                    message: message,
                    isRecoverable: true
                )
            )
            return SessionCompletion(
                outcome: .saveFailed(
                    message: message,
                    unresolvedUtteranceCount: unresolved
                ),
                message: "Transcript save failed",
                errorMessage: message
            )
        case .noTranscript where !didStartCapture && terminalFailureMessage == nil:
            return SessionCompletion(
                outcome: .cancelledBeforeCapture,
                message: "Stopped before listening",
                errorMessage: nil
            )
        case .noTranscript:
            return SessionCompletion(
                outcome: .failedBeforeCapture,
                message: "Session failed before listening",
                errorMessage: nil
            )
        case .saved:
            return successfulCompletion(unresolved: unresolved)
        }
    }

    private func successfulCompletion(unresolved: Int) -> SessionCompletion {
        guard unresolved > 0 else {
            return SessionCompletion(
                outcome: .saved,
                message: "Transcript saved",
                errorMessage: nil
            )
        }
        return SessionCompletion(
            outcome: .savedWithUnresolvedUtterances(count: unresolved),
            message: "Transcript saved with \(unresolved) unfinished sentence(s)",
            errorMessage: nil
        )
    }
}
