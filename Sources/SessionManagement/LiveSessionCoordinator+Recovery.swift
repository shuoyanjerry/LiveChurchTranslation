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
        let issue = LiveSessionIssue(
            stage: failure.stage,
            utteranceSequence: segment.sequenceNumber,
            message: failure.message,
            isRecoverable: true
        )
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
        sessionFinalizer.logRecoverable(failure)
    }
}
