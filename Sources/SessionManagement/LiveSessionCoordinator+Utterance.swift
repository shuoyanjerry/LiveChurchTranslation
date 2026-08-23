import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

struct TerminalSentenceRejection: Sendable {
    let receipt: UtteranceRejectionReceipt
    let failure: UtteranceProcessingFailure
}

struct SegmentProcessingOutcome: Sendable {
    let lastPersistedEntry: TranscriptEntry?
    let rejections: [TerminalSentenceRejection]
}

private enum LiveSentenceProcessingResult {
    case translated(TranscriptEntry)
    case rejected(TerminalSentenceRejection)
    case deferred(UtteranceProcessingFailure)
}

extension LiveSessionCoordinator {
    func processQueuedRecord(
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) async {
        let segment = record.segment
        transitionWhileActive(to: .recognizing, message: "正在识别语音…")
        do {
            let outcome = try await translate(record, sessionID: sessionID)
            try await completeRecovery(record, outcome: outcome)
        } catch let ignored as IgnoredUtterance {
            await discardFiltered(record, reason: ignored.message)
        } catch let failure as UtteranceProcessingFailure
            where failure.impact == .retryableUtterance
        {
            deferForRetry(record, failure: failure)
        } catch let failure as UtteranceProcessingFailure
            where failure.impact == .terminalUtterance
        {
            await completeTerminalRejection(record, failure: failure)
        } catch let failure as UtteranceProcessingFailure {
            preserve(segment, after: failure, recoveryID: record.id)
        } catch is CancellationError {
            return
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
    ) async throws -> SegmentProcessingOutcome {
        let segment = record.segment
        let sentences = try await utteranceProcessor.recognize(segment)
        var finalEntry: TranscriptEntry?
        var rejections: [TerminalSentenceRejection] = []
        var deferredFailure: UtteranceProcessingFailure?
        for (ordinal, sentence) in sentences.enumerated() {
            transitionWhileActive(to: .translating, message: "正在忠实翻译…")
            switch try await processSentence(
                sentence,
                ordinal: ordinal,
                sessionID: sessionID
            ) {
            case .translated(let entry):
                publishTranslated(entry, sentenceTail: sentence.utterance.endedAt)
                finalEntry = entry
            case .rejected(let rejection):
                rejections.append(rejection)
            case .deferred(let failure):
                deferredFailure = deferredFailure ?? failure
            }
        }
        if let deferredFailure { throw deferredFailure }
        guard finalEntry != nil || !rejections.isEmpty else {
            throw IgnoredUtterance(message: "未识别到可处理的句子。")
        }
        return SegmentProcessingOutcome(
            lastPersistedEntry: finalEntry,
            rejections: rejections
        )
    }

    private func processSentence(
        _ sentence: UtteranceProcessor.RecognizedInput,
        ordinal: Int,
        sessionID: UUID
    ) async throws -> LiveSentenceProcessingResult {
        do {
            return .translated(
                try await utteranceProcessor.translate(sentence, sessionID: sessionID)
            )
        } catch let failure as UtteranceProcessingFailure
            where failure.impact == .retryableUtterance
        {
            await utteranceProcessor.acceptSourceDiscourse(afterTerminalTranslation: sentence)
            return .deferred(failure)
        } catch let failure as UtteranceProcessingFailure
            where failure.impact == .terminalUtterance
        {
            await utteranceProcessor.acceptSourceDiscourse(afterTerminalTranslation: sentence)
            return .rejected(
                TerminalSentenceRejection(
                    receipt: rejectionReceipt(
                        sentenceID: sentence.utterance.sourceSegmentID,
                        ordinal: ordinal,
                        failure: failure
                    ),
                    failure: failure
                )
            )
        }
    }

    private func publishTranslated(_ entry: TranscriptEntry, sentenceTail: Duration) {
        state.append(entry)
        publish(.transcriptAppended(entry))
        recordVisibility(of: entry, sentenceTail: sentenceTail)
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
