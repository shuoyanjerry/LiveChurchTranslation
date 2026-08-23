import Foundation
import SettingsAPI
import TranscriptAPI
import TranslationAPI
import UtteranceRecoveryAPI

extension UtteranceProcessor {
    func recoverEntry(
        _ record: PendingUtteranceRecord,
        input: RecognizedInput,
        translationContext: [TranslationContextEntry],
        presentationSequence: Int
    ) async throws -> TranscriptEntry {
        let translation = try await translateRecovered(input, context: translationContext)
        let entry = makeRecoveredEntry(
            record: record,
            input: input,
            translation: translation,
            presentationSequence: presentationSequence
        )
        return try await persistRecovered(entry, sessionID: record.id.sessionID)
    }

    private func translateRecovered(
        _ input: RecognizedInput,
        context: [TranslationContextEntry]
    ) async throws -> TranslationResult {
        do {
            return try await dependencies.translator.translate(
                TranslationRequest(
                    sourceText: input.utterance.text,
                    sourceLanguage: mode.sourceLanguageTag,
                    targetLanguage: mode.targetLanguageTag,
                    glossary: matchedTerms(
                        in: input.utterance.text,
                        entries: input.glossary,
                        mode: mode
                    ),
                    context: context,
                    pronounGuidance: input.pronounGuidance
                )
            )
        } catch {
            if error is CancellationError { throw CancellationError() }
            throw failure(stage: .translation, error: error)
        }
    }

    private func makeRecoveredEntry(
        record: PendingUtteranceRecord,
        input: RecognizedInput,
        translation: TranslationResult,
        presentationSequence: Int
    ) -> TranscriptEntry {
        TranscriptEntry(
            id: input.utterance.sourceSegmentID,
            sequence: presentationSequence,
            sourceSegmentSequence: record.id.sequenceNumber,
            rawSourceText: input.sourceAudit.rawText,
            sourceText: input.utterance.text,
            sourceCorrections: input.sourceAudit.corrections,
            sourcePronounDecisions: input.sourceAudit.pronounDecisions,
            targetText: translation.targetText,
            translationReview: translation.review,
            startedMilliseconds: milliseconds(input.utterance.startedAt),
            endedMilliseconds: milliseconds(input.utterance.endedAt),
            translationMilliseconds: milliseconds(translation.duration)
        )
    }

    private func persistRecovered(
        _ entry: TranscriptEntry,
        sessionID: UUID
    ) async throws -> TranscriptEntry {
        do {
            try await dependencies.transcriptStore.append(entry, to: sessionID)
            return entry
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw failure(stage: .persistence, error: error, pendingEntry: entry)
        }
    }

    private func milliseconds(_ duration: Duration) -> Int64 {
        let parts = duration.components
        let seconds = parts.seconds.multipliedReportingOverflow(by: 1_000).partialValue
        return seconds + Int64(parts.attoseconds / 1_000_000_000_000_000)
    }
}
