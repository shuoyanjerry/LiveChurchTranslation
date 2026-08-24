import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

struct RecoveredSentenceRequest {
    let input: UtteranceProcessor.RecognizedInput
    let context: [TranslationContextEntry]
    let presentationSequence: Int
    let ordinal: Int
    let processingStyle: RecoveredSessionProcessingStyle
}

enum RecoveredSentenceResult {
    case entry(TranscriptEntry)
    case rejection(TerminalSentenceRejection)
}

extension UtteranceRecoveryReplayer {
    func recoverSentence(
        _ request: RecoveredSentenceRequest,
        record: PendingUtteranceRecord
    ) async throws -> RecoveredSentenceResult {
        do {
            return .entry(try await recoveredEntry(request, record: record))
        } catch let failure as UtteranceProcessingFailure {
            guard failure.impact == .terminalUtterance else { throw failure }
            return .rejection(
                TerminalSentenceRejection(
                    receipt: rejectionReceipt(
                        sentenceID: request.input.utterance.sourceSegmentID,
                        ordinal: request.ordinal,
                        failure: failure
                    ),
                    failure: failure
                )
            )
        }
    }

    private func recoveredEntry(
        _ request: RecoveredSentenceRequest,
        record: PendingUtteranceRecord
    ) async throws -> TranscriptEntry {
        switch request.processingStyle {
        case .sourceOnly:
            try await processor.recoverSourceEntry(
                record,
                input: request.input,
                presentationSequence: request.presentationSequence
            )
        case .translated:
            try await processor.recoverEntry(
                record,
                input: request.input,
                translationContext: request.context,
                presentationSequence: request.presentationSequence
            )
        }
    }
}
