import Foundation
import SessionManagementAPI
import UtteranceRecoveryAPI

enum DiskRecoveryMode: Sendable, Equatable {
    case backlog(UtteranceQueueLimit)
    case processingFailure
    case recoveryStoreFailure
}

extension LiveSessionCoordinator {
    func enqueueOrDefer(
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) {
        guard diskRecoveryMode == nil else {
            deferToDiskRecovery(record)
            return
        }
        switch segmentQueue.enqueue(record) {
        case .admitted:
            if inferenceIsReady {
                startWorkerIfNeeded(sessionID: sessionID)
            }
        case .rejected(let limit):
            enterBacklogRecoveryMode(trigger: record, limit: limit)
        }
    }

    func enterProcessingFailureRecoveryMode(hasDurableRecord: Bool) {
        if !hasDurableRecord {
            diskRecoveryMode = .recoveryStoreFailure
            deferQueuedRecords()
            publishRecoveryCaptureStatus()
            return
        }
        guard diskRecoveryMode == nil else { return }
        diskRecoveryMode = .processingFailure
        deferQueuedRecords()
        publishRecoveryCaptureStatus()
    }

    private func enterBacklogRecoveryMode(
        trigger: PendingUtteranceRecord,
        limit: UtteranceQueueLimit
    ) {
        guard diskRecoveryMode == nil else {
            deferToDiskRecovery(trigger)
            return
        }
        diskRecoveryMode = .backlog(limit)
        deferQueuedRecords()
        deferToDiskRecovery(trigger)
        let issue = LiveSessionIssue(
            stage: .audioProcessing,
            utteranceSequence: trigger.id.sequenceNumber,
            message: backlogRecoveryMessage,
            isRecoverable: true
        )
        state.record(issue)
        publishRecoveryCaptureStatus()
        publish(.recoverableError(issue.message))
    }

    private func deferQueuedRecords() {
        while let queued = segmentQueue.dequeue() {
            deferToDiskRecovery(queued)
        }
    }

    func deferToDiskRecovery(_: PendingUtteranceRecord) {
        incrementUnresolvedUtteranceCount()
    }

    func incrementUnresolvedUtteranceCount() {
        if unresolvedUtteranceCount < Int.max {
            unresolvedUtteranceCount += 1
        }
    }

    func deferQueuedRecordsUntilNextSession() {
        guard !segmentQueue.isEmpty else { return }
        if diskRecoveryMode == nil {
            diskRecoveryMode = .processingFailure
        }
        deferQueuedRecords()
    }

    func captureStatusMessage(normal: String) -> String {
        guard diskRecoveryMode != nil else {
            let recovery =
                unresolvedUtteranceCount > 0
                ? "\(unresolvedUtteranceCount) 句等待恢复"
                : nil
            let rejected =
                terminalRejectedSentenceCount > 0
                ? "\(terminalRejectedSentenceCount) 句未通过质量校验"
                : nil
            let details = [recovery, rejected].compactMap { $0 }
            return details.isEmpty ? normal : "\(normal) · \(details.joined(separator: " · "))"
        }
        return recoveryCaptureStatusMessage
    }

    private func publishRecoveryCaptureStatus() {
        if isActive {
            state.transition(to: .listening, message: recoveryCaptureStatusMessage)
        }
        publishState()
    }

    private var backlogRecoveryMessage: String {
        "实时翻译因待处理内容达到安全上限而暂停。"
            + "未完成的语句已保存到磁盘，稍后会自动恢复；会议完整录音仍在继续。"
    }

    private var recoveryCaptureStatusMessage: String {
        switch diskRecoveryMode {
        case .recoveryStoreFailure:
            "录音继续进行。请稍后使用已保存的会议录音重试未完成的听抄。"
        case .backlog, .processingFailure:
            "录音继续进行。未完成的语句将在下次启动时自动恢复。"
        case nil:
            "正在聆听"
        }
    }
}
