import Foundation
import SessionManagementAPI
import UtteranceRecoveryAPI
import VADAPI

extension LiveSessionCoordinator {
    func rejectionReceipt(
        sentenceID: UUID,
        ordinal: Int,
        failure: UtteranceProcessingFailure
    ) -> UtteranceRejectionReceipt {
        let stage: UtteranceRejectionStage
        switch failure.stage {
        case .recognition:
            stage = .recognition
        case .translation:
            stage = .translation
        case .preparation, .audioProcessing, .persistence, .finalization:
            preconditionFailure("Only inference failures can become terminal rejections")
        }
        return UtteranceRejectionReceipt(
            sentenceID: sentenceID,
            sentenceOrdinal: ordinal,
            stage: stage,
            failureCode: failure.code
        )
    }

    func recordTerminalRejections(
        _ rejections: [TerminalSentenceRejection],
        segment: SpeechSegment
    ) {
        guard !rejections.isEmpty else { return }
        rejections.forEach { recordTerminalRejection($0, segment: segment) }
        if processingPolicy.requiresCompleteCapture {
            terminalFailureMessage =
                terminalFailureMessage
                ?? "媒体听抄不完整：有内容未通过本地质量校验。完整录音已保留。"
        }
        publishContinuingStatus()
    }

    func importFailureMessage(hasDurableRecord: Bool) -> String {
        let recovery =
            hasDurableRecord
            ? "未完成的片段已保留，稍后可自动恢复。"
            : "完整的导入音频仍然保留，请重新处理原始文件。"
        return "媒体听抄未完成。\(recovery)"
    }

    private func recordTerminalRejection(
        _ rejection: TerminalSentenceRejection,
        segment: SpeechSegment
    ) {
        if terminalRejectedSentenceCount < Int.max {
            terminalRejectedSentenceCount += 1
        }
        state.record(
            LiveSessionIssue(
                stage: rejection.failure.stage,
                utteranceSequence: segment.sequenceNumber,
                message: rejection.failure.message,
                isRecoverable: false
            )
        )
        sessionFinalizer.logRecoverable(rejection.failure)
    }
}
