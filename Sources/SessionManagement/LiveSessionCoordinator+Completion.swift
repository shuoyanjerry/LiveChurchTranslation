import Foundation
import SessionManagementAPI
import TranscriptAPI

extension LiveSessionCoordinator {
    func completion(
        from result: SessionPersistenceResult,
        sessionID: UUID
    ) -> SessionCompletion {
        let unresolved = unresolvedUtteranceCount
        let rejected = terminalRejectedSentenceCount
        switch result {
        case .failed(let transcript, _):
            return failedCompletion(
                transcript: transcript,
                sessionID: sessionID,
                unresolved: unresolved
            )
        case .noTranscript where !didStartCapture && terminalFailureMessage == nil:
            return SessionCompletion(
                outcome: .cancelledBeforeCapture,
                message: "尚未开始聆听，已停止",
                errorMessage: nil
            )
        case .noTranscript:
            return SessionCompletion(
                outcome: .failedBeforeCapture,
                message: "会话在开始聆听前失败",
                errorMessage: nil
            )
        case .saved(let finalization):
            return successfulCompletion(
                unresolved: max(unresolved, finalization.pendingRecordCount),
                rejected: max(rejected, finalization.rejections.count),
                hasOtherIncompleteData: finalization.quarantinedArtifactCount > 0
                    || finalization.hasUnrecoverableFailure
            )
        }
    }

    private func failedCompletion(
        transcript: TranscriptSession,
        sessionID: UUID,
        unresolved: Int
    ) -> SessionCompletion {
        let userMessage = "听抄稿保存失败，请稍后重试。"
        unsavedTranscripts[sessionID] = transcript
        state.record(
            LiveSessionIssue(
                stage: .finalization,
                message: userMessage,
                isRecoverable: true
            )
        )
        return SessionCompletion(
            outcome: .saveFailed(
                message: userMessage,
                unresolvedUtteranceCount: unresolved
            ),
            message: userMessage,
            errorMessage: userMessage
        )
    }

    private func successfulCompletion(
        unresolved: Int,
        rejected: Int,
        hasOtherIncompleteData: Bool
    ) -> SessionCompletion {
        if rejected > 0 || hasOtherIncompleteData {
            return SessionCompletion(
                outcome: .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: rejected,
                    recoverableUtteranceCount: unresolved
                ),
                message: incompleteCompletionMessage(
                    rejected: rejected,
                    hasOtherIncompleteData: hasOtherIncompleteData
                ),
                errorMessage: nil
            )
        }
        guard unresolved > 0 else {
            return SessionCompletion(
                outcome: .saved,
                message: "听抄稿已保存",
                errorMessage: nil
            )
        }
        return SessionCompletion(
            outcome: .savedWithUnresolvedUtterances(count: unresolved),
            message: "听抄稿已保存，仍有 \(unresolved) 句待恢复",
            errorMessage: nil
        )
    }

    private func incompleteCompletionMessage(
        rejected: Int,
        hasOtherIncompleteData: Bool
    ) -> String {
        if rejected > 0 {
            return "听抄稿已保存，其中 \(rejected) 句未通过质量校验"
        }
        if hasOtherIncompleteData {
            return "听抄稿已保存，但存在无法自动恢复的未完整内容"
        }
        return "听抄稿已保存"
    }
}
