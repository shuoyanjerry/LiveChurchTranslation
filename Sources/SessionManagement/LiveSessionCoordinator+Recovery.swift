import DiagnosticsAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

extension LiveSessionCoordinator {
    func deferForRetry(
        _ record: PendingUtteranceRecord,
        failure: UtteranceProcessingFailure
    ) {
        if processingPolicy.requiresCompleteCapture {
            terminalFailureMessage =
                terminalFailureMessage
                ?? importFailureMessage(hasDurableRecord: true)
        }
        incrementUnresolvedUtteranceCount()
        let issue = LiveSessionIssue(
            stage: failure.stage,
            utteranceSequence: record.segment.sequenceNumber,
            message: failure.message,
            isRecoverable: true
        )
        if pendingUtterances.count < segmentQueue.policy.maximumRecords {
            pendingUtterances.append(
                PendingUtterance(
                    segment: record.segment,
                    issue: issue,
                    translatedEntry: failure.pendingEntry,
                    recoveryID: record.id
                )
            )
            state.record(issue)
        }
        publish(.recoverableError(issue.message))
        sessionFinalizer.logRecoverable(failure)
        publishContinuingStatus()
    }

    func discardFiltered(
        _ record: PendingUtteranceRecord,
        reason: String
    ) async {
        do {
            try await dependencies.recoveryStore.resolve(record.id, as: .ignored)
            await dependencies.diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "ASRFilter",
                    message: reason
                )
            )
        } catch is CancellationError {
            return
        } catch {
            preserve(
                record.segment,
                after: UtteranceProcessingFailure(
                    stage: .persistence,
                    message: error.localizedDescription,
                    pendingEntry: nil
                ),
                recoveryID: record.id
            )
        }
    }

    func completeRecovery(
        _ record: PendingUtteranceRecord,
        outcome: SegmentProcessingOutcome
    ) async throws {
        do {
            let resolution: UtteranceRecoveryResolution =
                outcome.rejections.isEmpty
                ? .completed
                : .terminallyRejected(outcome.rejections.map(\.receipt))
            try await dependencies.recoveryStore.resolve(record.id, as: resolution)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw UtteranceProcessingFailure(
                stage: .persistence,
                message: error.localizedDescription,
                pendingEntry: outcome.lastPersistedEntry
            )
        }
        recordTerminalRejections(outcome.rejections, segment: record.segment)
    }

    func completeTerminalRejection(
        _ record: PendingUtteranceRecord,
        failure: UtteranceProcessingFailure
    ) async {
        let rejection = TerminalSentenceRejection(
            receipt: rejectionReceipt(
                sentenceID: record.segment.id,
                ordinal: 0,
                failure: failure
            ),
            failure: failure
        )
        do {
            try await dependencies.recoveryStore.resolve(
                record.id,
                as: .terminallyRejected([rejection.receipt])
            )
            recordTerminalRejections([rejection], segment: record.segment)
        } catch is CancellationError {
            return
        } catch {
            preserve(
                record.segment,
                after: UtteranceProcessingFailure(
                    stage: .persistence,
                    message: error.localizedDescription,
                    pendingEntry: nil
                ),
                recoveryID: record.id
            )
        }
    }

    func preserve(
        _ segment: SpeechSegment,
        after failure: UtteranceProcessingFailure,
        recoveryID: PendingUtteranceID? = nil
    ) {
        if recoveryID == nil {
            hasUnrecoverableSessionFailure = true
        }
        if processingPolicy.requiresCompleteCapture {
            terminalFailureMessage =
                terminalFailureMessage
                ?? importFailureMessage(hasDurableRecord: recoveryID != nil)
        }
        incrementUnresolvedUtteranceCount()
        let issue = LiveSessionIssue(
            stage: failure.stage,
            utteranceSequence: segment.sequenceNumber,
            message: failure.message,
            isRecoverable: true
        )
        if pendingUtterances.count < segmentQueue.policy.maximumRecords {
            pendingUtterances.append(
                PendingUtterance(
                    segment: segment,
                    issue: issue,
                    translatedEntry: failure.pendingEntry,
                    recoveryID: recoveryID
                )
            )
            state.record(issue)
            publishState()
        }
        publish(.recoverableError(issue.message))
        enterProcessingFailureRecoveryMode(hasDurableRecord: recoveryID != nil)
        sessionFinalizer.logRecoverable(failure)
    }

    func publishContinuingStatus() {
        guard isActive else { return }
        state.transition(
            to: .listening,
            message: captureStatusMessage(normal: "正在聆听")
        )
        publishState()
    }
}
