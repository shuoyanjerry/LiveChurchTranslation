import ASRAPI
import Foundation
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

extension UtteranceRecoveryReplayer {
    func replayRecord(
        _ record: PendingUtteranceRecord,
        entries: inout [TranscriptEntry]
    ) async -> RecoveryRecordReplayResult {
        do {
            let rejections = try await replaySentences(record, entries: &entries)
            return try await resolvedReplayResult(for: record, rejections: rejections)
        } catch is CancellationError {
            return .blockedWithoutIssue
        } catch let failure as UtteranceProcessingFailure {
            return await processingFailureResult(record, failure: failure)
        } catch {
            return blockedResult(
                issue(
                    sequence: record.id.sequenceNumber,
                    message: error.localizedDescription
                )
            )
        }
    }

    private func replaySentences(
        _ record: PendingUtteranceRecord,
        entries: inout [TranscriptEntry]
    ) async throws -> [TerminalSentenceRejection] {
        let context = contextEntries(from: entries, before: record.id.sequenceNumber)
        let recognizedInputs = try await processor.recognize(
            record.segment,
            discourseContext: context.discourse
        )
        let inputs = try await processor.recoveryInputs(
            for: recognizedInputs,
            record: record,
            persistedEntries: entries
        )
        try requireProcessableInputs(inputs)
        var translationContext = context.translation
        var rejections: [TerminalSentenceRejection] = []
        for (ordinal, input) in inputs.enumerated() {
            if let existing = existingEntry(for: input, in: entries) {
                appendContext(existing, to: &translationContext)
                continue
            }
            let result = try await recoverSentence(
                input,
                record: record,
                context: translationContext,
                presentationSequence: context.presentationSequence + ordinal,
                ordinal: ordinal
            )
            switch result {
            case .entry(let entry):
                entries.append(entry)
                appendContext(entry, to: &translationContext)
            case .rejection(let rejection):
                rejections.append(rejection)
            }
        }
        return rejections
    }

    private func requireProcessableInputs(
        _ inputs: [UtteranceProcessor.RecognizedInput]
    ) throws {
        guard !inputs.isEmpty else {
            throw terminalRecognitionFailure(.noProcessableSentences)
        }
    }

    private func resolvedReplayResult(
        for record: PendingUtteranceRecord,
        rejections: [TerminalSentenceRejection]
    ) async throws -> RecoveryRecordReplayResult {
        let resolution: UtteranceRecoveryResolution =
            rejections.isEmpty
            ? .completed
            : .terminallyRejected(rejections.map(\.receipt))
        try await dependencies.recoveryStore.resolve(record.id, as: resolution)
        return RecoveryRecordReplayResult(
            issues: rejections.map {
                issue(
                    stage: $0.failure.stage,
                    sequence: record.id.sequenceNumber,
                    message: $0.failure.message,
                    isRecoverable: false
                )
            },
            isBlocked: false,
            terminalRejectionCount: rejections.count
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

    private func existingEntry(
        for input: UtteranceProcessor.RecognizedInput,
        in entries: [TranscriptEntry]
    ) -> TranscriptEntry? {
        entries.first { $0.id == input.utterance.sourceSegmentID }
    }

    private func recoverSentence(
        _ input: UtteranceProcessor.RecognizedInput,
        record: PendingUtteranceRecord,
        context: [TranslationContextEntry],
        presentationSequence: Int,
        ordinal: Int
    ) async throws -> RecoveredSentenceResult {
        do {
            return .entry(
                try await processor.recoverEntry(
                    record,
                    input: input,
                    translationContext: context,
                    presentationSequence: presentationSequence
                )
            )
        } catch let failure as UtteranceProcessingFailure {
            guard failure.impact == .terminalUtterance else { throw failure }
            return .rejection(
                TerminalSentenceRejection(
                    receipt: rejectionReceipt(
                        sentenceID: input.utterance.sourceSegmentID,
                        ordinal: ordinal,
                        failure: failure
                    ),
                    failure: failure
                )
            )
        }
    }

    private func appendContext(
        _ entry: TranscriptEntry,
        to context: inout [TranslationContextEntry]
    ) {
        guard entry.translationReview == nil else { return }
        context.append(
            TranslationContextEntry(
                sourceText: entry.sourceText,
                targetText: entry.targetText
            )
        )
        if context.count > 2 {
            context.removeFirst(context.count - 2)
        }
    }
}

private enum RecoveredSentenceResult {
    case entry(TranscriptEntry)
    case rejection(TerminalSentenceRejection)
}
