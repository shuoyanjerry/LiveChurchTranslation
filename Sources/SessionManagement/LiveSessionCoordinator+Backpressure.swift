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
        guard diskRecoveryMode != nil else { return normal }
        return recoveryCaptureStatusMessage
    }

    private func publishRecoveryCaptureStatus() {
        if isActive {
            state.transition(to: .listening, message: recoveryCaptureStatusMessage)
        }
        publishState()
    }

    private var backlogRecoveryMessage: String {
        "Live translation paused because its safe in-memory backlog was reached. "
            + "Unfinished sentences are stored on disk for automatic recovery, "
            + "and the complete meeting recording continues."
    }

    private var recoveryCaptureStatusMessage: String {
        switch diskRecoveryMode {
        case .recoveryStoreFailure:
            "Recording continues. Use the saved meeting audio to retry unfinished transcription."
        case .backlog, .processingFailure:
            "Recording continues. Unfinished sentences will recover automatically next time."
        case nil:
            "Listening"
        }
    }
}
