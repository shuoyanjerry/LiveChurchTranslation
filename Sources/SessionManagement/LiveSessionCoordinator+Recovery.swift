import DiagnosticsAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

extension LiveSessionCoordinator {
    func discardFiltered(
        _ record: PendingUtteranceRecord,
        reason: String
    ) async {
        do {
            try await dependencies.recoveryStore.markCompleted(record.id)
            await dependencies.diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "ASRFilter",
                    message: reason
                )
            )
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
        translatedEntry: TranscriptEntry
    ) async throws {
        do {
            try await dependencies.recoveryStore.markCompleted(record.id)
        } catch {
            throw UtteranceProcessingFailure(
                stage: .persistence,
                message: error.localizedDescription,
                pendingEntry: translatedEntry
            )
        }
    }

    func preserve(
        _ segment: SpeechSegment,
        after failure: UtteranceProcessingFailure,
        recoveryID: PendingUtteranceID? = nil
    ) {
        if processingPolicy.requiresCompleteCapture {
            terminalFailureMessage =
                terminalFailureMessage
                ?? importFailureMessage(failure, hasDurableRecord: recoveryID != nil)
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
            publish(.recoverableError(issue.message))
        }
        enterProcessingFailureRecoveryMode(hasDurableRecord: recoveryID != nil)
        sessionFinalizer.logRecoverable(failure)
    }

    private func importFailureMessage(
        _ failure: UtteranceProcessingFailure,
        hasDurableRecord: Bool
    ) -> String {
        let recovery =
            hasDurableRecord
            ? "The unfinished segment was kept for recovery."
            : "Retry the original file; the complete imported recording remains available."
        return "Audio import is incomplete. \(recovery) \(failure.message)"
    }
}
