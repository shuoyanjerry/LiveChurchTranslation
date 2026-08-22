import Foundation
import SessionManagementAPI

struct SessionCompletion: Sendable {
    let outcome: LiveSessionFinalizationOutcome
    let message: String
    let errorMessage: String?
}

extension LiveSessionCoordinator {
    func finishAfterCaptureEnded(sessionID: UUID, failure: String?) async {
        guard state.sessionID == sessionID else { return }
        if let failure {
            terminalFailureMessage = failure
            recordIssue(stage: .audioProcessing, message: failure, isRecoverable: true)
        }
        await stop()
    }

    func acceptsFrames(for sessionID: UUID) -> Bool {
        state.sessionID == sessionID
    }

    func performStop(sessionID: UUID) async {
        let preparation = preparationTask
        await sessionPreparer.cancel()
        await dependencies.capture.stopCapture()
        _ = await preparation?.result
        preparationTask = nil

        let capture = captureTask
        await capture?.value
        captureTask = nil
        for event in await dependencies.vad.flush() {
            await handle(event, sessionID: sessionID)
        }
        await workerTask?.value
        await finishSession(sessionID: sessionID)
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
        segmentQueue.removeAll(keepingCapacity: false)
        if let failure {
            state.fail(failure, outcome: completion.outcome)
        } else {
            state.finish(outcome: completion.outcome, message: completion.message)
        }
        modelTask?.cancel()
        modelTask = nil
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
        let unresolved = pendingUtterances.count
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
