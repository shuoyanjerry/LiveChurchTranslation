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
            let entry = try await translate(record, sessionID: sessionID)
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
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) async throws -> TranscriptEntry {
        let segment = record.segment
        let sentences = try await utteranceProcessor.recognize(segment)
        var finalEntry: TranscriptEntry?
        for sentence in sentences {
            transitionWhileActive(to: .translating, message: "Translating faithfully…")
            let entry = try await utteranceProcessor.translate(
                sentence,
                sessionID: sessionID
            )
            state.append(entry)
            publish(.transcriptAppended(entry))
            recordVisibility(of: entry, sentenceTail: sentence.utterance.endedAt)
            finalEntry = entry
        }
        guard let finalEntry else { throw IgnoredUtterance(message: "No sentence recognized") }
        return finalEntry
    }

    private func transitionWhileActive(to phase: LiveSessionPhase, message: String) {
        guard isActive else { return }
        state.transition(to: phase, message: message)
        publishState()
    }

    private func recordVisibility(
        of entry: TranscriptEntry,
        sentenceTail: Duration
    ) {
        guard let anchor = sentenceAudioTimelineAnchor else { return }
        let event = SentenceRealtimePolicy.diagnostic(
            sourceSegmentSequence: entry.sourceSegmentSequence ?? 0,
            presentationSequence: entry.sequence,
            sentenceTail: sentenceTail,
            tailObservedAt: anchor.monotonicTime(for: sentenceTail),
            visibleAt: sentenceVisibilityClock.now()
        )
        let diagnostics = dependencies.diagnostics
        Task { await diagnostics.record(event) }
    }
}
