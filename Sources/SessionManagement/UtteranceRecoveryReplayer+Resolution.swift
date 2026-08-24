import Foundation
import SessionManagementAPI
import UtteranceRecoveryAPI

extension UtteranceRecoveryReplayer {
    func processingFailureResult(
        _ record: PendingUtteranceRecord,
        failure: UtteranceProcessingFailure
    ) async -> RecoveryRecordReplayResult {
        switch failure.impact {
        case .terminalUtterance:
            return await completeTerminalRejection(record, failure: failure)
        case .retryableUtterance:
            return deferredResult(record, failure: failure)
        case .pipeline:
            return blockedResult(
                issue(
                    stage: failure.stage,
                    sequence: record.id.sequenceNumber,
                    message: failure.message
                )
            )
        }
    }

    func completeTerminalRejection(
        _ record: PendingUtteranceRecord,
        failure: UtteranceProcessingFailure
    ) async -> RecoveryRecordReplayResult {
        let receipt = rejectionReceipt(
            sentenceID: record.segment.id,
            ordinal: 0,
            failure: failure
        )
        do {
            try await dependencies.recoveryStore.resolve(
                record.id,
                as: .terminallyRejected([receipt])
            )
            return terminalRejectionResult(record, failure: failure)
        } catch is CancellationError {
            return .blockedWithoutIssue
        } catch {
            return blockedResult(
                issue(
                    stage: .persistence,
                    sequence: record.id.sequenceNumber,
                    message: error.localizedDescription
                )
            )
        }
    }

    func rejectionReceipt(
        sentenceID: UUID,
        ordinal: Int,
        failure: UtteranceProcessingFailure
    ) -> UtteranceRejectionReceipt {
        let stage: UtteranceRejectionStage
        switch failure.stage {
        case .recognition: stage = .recognition
        case .translation: stage = .translation
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

    func blockedResult(_ issue: LiveSessionIssue) -> RecoveryRecordReplayResult {
        RecoveryRecordReplayResult(
            issues: [issue],
            isBlocked: true,
            terminalRejectionCount: 0
        )
    }

    private func deferredResult(
        _ record: PendingUtteranceRecord,
        failure: UtteranceProcessingFailure
    ) -> RecoveryRecordReplayResult {
        RecoveryRecordReplayResult(
            issues: [
                issue(
                    stage: failure.stage,
                    sequence: record.id.sequenceNumber,
                    message: failure.message
                )
            ],
            isBlocked: false,
            terminalRejectionCount: 0
        )
    }

    private func terminalRejectionResult(
        _ record: PendingUtteranceRecord,
        failure: UtteranceProcessingFailure
    ) -> RecoveryRecordReplayResult {
        RecoveryRecordReplayResult(
            issues: [
                issue(
                    stage: failure.stage,
                    sequence: record.id.sequenceNumber,
                    message: failure.message,
                    isRecoverable: false
                )
            ],
            isBlocked: false,
            terminalRejectionCount: 1
        )
    }
}

struct RecoveryRecordReplayResult: Sendable {
    let issues: [LiveSessionIssue]
    let isBlocked: Bool
    let terminalRejectionCount: Int

    static let resolvedWithoutIssue = Self(
        issues: [],
        isBlocked: false,
        terminalRejectionCount: 0
    )
    static let blockedWithoutIssue = Self(
        issues: [],
        isBlocked: true,
        terminalRejectionCount: 0
    )
}
