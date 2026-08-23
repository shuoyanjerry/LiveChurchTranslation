import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

extension LiveSessionCoordinator {
    func processQueuedRecord(
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) async {
        let segment = record.segment
        transitionWhileActive(to: .recognizing, message: "Recognizing speech…")
        do {
            let entry = try await translate(segment, sessionID: sessionID)
            try await completeRecovery(record, translatedEntry: entry)
        } catch let ignored as IgnoredUtterance {
            await discardFiltered(record, reason: ignored.message)
        } catch let failure as UtteranceProcessingFailure {
            preserve(segment, after: failure, recoveryID: record.id)
        } catch {
            preserve(
                segment,
                after: UtteranceProcessingFailure(
                    stage: .recognition,
                    message: error.localizedDescription,
                    pendingEntry: nil
                ),
                recoveryID: record.id
            )
        }
    }

    private func translate(
        _ segment: SpeechSegment,
        sessionID: UUID
    ) async throws -> TranscriptEntry {
        let recognized = try await utteranceProcessor.recognize(segment)
        transitionWhileActive(to: .translating, message: "Translating faithfully…")
        let entry = try await utteranceProcessor.translate(
            recognized,
            sessionID: sessionID
        )
        state.append(entry)
        publish(.transcriptAppended(entry))
        return entry
    }

    private func transitionWhileActive(to phase: LiveSessionPhase, message: String) {
        guard isActive else { return }
        state.transition(to: phase, message: message)
        publishState()
    }
}
