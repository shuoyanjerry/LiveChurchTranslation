import ASRAPI
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
    let lastCommittedEntry: TranscriptEntry?
    let rejections: [TerminalSentenceRejection]
}

private enum LiveSentenceProcessingResult {
    case committed(TranscriptEntry)
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
            let outcome = try await process(record, sessionID: sessionID)
            try await completeRecovery(record, outcome: outcome)
        } catch let failure as UtteranceProcessingFailure {
            await handle(failure, for: record)
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

    private func handle(
        _ failure: UtteranceProcessingFailure,
        for record: PendingUtteranceRecord
    ) async {
        switch failure.impact {
        case .retryableUtterance:
            deferForRetry(record, failure: failure)
        case .terminalUtterance:
            await completeTerminalRejection(record, failure: failure)
        case .pipeline:
            preserve(record.segment, after: failure, recoveryID: record.id)
        }
    }

    private func process(
        _ record: PendingUtteranceRecord,
        sessionID: UUID
    ) async throws -> SegmentProcessingOutcome {
        let segment = record.segment
        let sentences = try await utteranceProcessor.recognize(segment)
        var finalEntry: TranscriptEntry?
        var rejections: [TerminalSentenceRejection] = []
        var deferredFailure: UtteranceProcessingFailure?
        for (ordinal, sentence) in sentences.enumerated() {
            transitionForRecognizedSource()
            switch try await processSentence(
                sentence,
                ordinal: ordinal,
                sessionID: sessionID
            ) {
            case .committed(let entry):
                publishCommitted(entry, sentenceTail: sentence.utterance.endedAt)
                finalEntry = entry
            case .rejected(let rejection):
                rejections.append(rejection)
            case .deferred(let failure):
                deferredFailure = deferredFailure ?? failure
            }
        }
        if let deferredFailure { throw deferredFailure }
        guard finalEntry != nil || !rejections.isEmpty else {
            throw terminalRecognitionFailure(.noProcessableSentences)
        }
        return SegmentProcessingOutcome(
            lastCommittedEntry: finalEntry,
            rejections: rejections
        )
    }

    private func terminalRecognitionFailure(_ error: ASRError) -> UtteranceProcessingFailure {
        UtteranceProcessingFailure(
            stage: .recognition,
            code: error.asrFailureCode,
            message: error.localizedDescription,
            pendingEntry: nil,
            impact: .terminalUtterance
        )
    }

    private func processSentence(
        _ sentence: UtteranceProcessor.RecognizedInput,
        ordinal: Int,
        sessionID: UUID
    ) async throws -> LiveSentenceProcessingResult {
        do {
            let entry =
                if processingPolicy.transcribesOnly {
                    try await utteranceProcessor.transcribe(sentence, sessionID: sessionID)
                } else {
                    try await utteranceProcessor.translate(sentence, sessionID: sessionID)
                }
            return .committed(entry)
        } catch let failure as UtteranceProcessingFailure {
            return try await sentenceFailureResult(failure, sentence: sentence, ordinal: ordinal)
        }
    }

    private func sentenceFailureResult(
        _ failure: UtteranceProcessingFailure,
        sentence: UtteranceProcessor.RecognizedInput,
        ordinal: Int
    ) async throws -> LiveSentenceProcessingResult {
        switch failure.impact {
        case .retryableUtterance:
            await utteranceProcessor.acceptSourceDiscourse(afterTerminalOutcome: sentence)
            return .deferred(failure)
        case .terminalUtterance:
            await utteranceProcessor.acceptSourceDiscourse(afterTerminalOutcome: sentence)
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
        case .pipeline:
            throw failure
        }
    }

}
