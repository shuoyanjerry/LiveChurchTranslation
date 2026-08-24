import Foundation
import TranscriptAPI
import UtteranceRecoveryAPI

extension UtteranceProcessor {
    func transcribe(_ input: RecognizedInput, sessionID: UUID) async throws -> TranscriptEntry {
        guard let transcript = await dependencies.transcript.snapshot() else {
            throw failure(stage: .persistence, error: TranscriptBufferError.noActiveSession)
        }
        let entry = sourceEntry(input, presentationSequence: transcript.entries.count + 1)
        try await persist(entry, sessionID: sessionID)
        if input.isFinalInSourceSegment {
            acceptSourceDiscourse(afterTerminalOutcome: input)
        }
        await dependencies.transcript.append(entry)
        return entry
    }

    func recoverSourceEntry(
        _ record: PendingUtteranceRecord,
        input: RecognizedInput,
        presentationSequence: Int
    ) async throws -> TranscriptEntry {
        let entry = sourceEntry(input, presentationSequence: presentationSequence)
        try await persist(entry, sessionID: record.id.sessionID)
        return entry
    }

    private func sourceEntry(
        _ input: RecognizedInput,
        presentationSequence: Int
    ) -> TranscriptEntry {
        TranscriptEntry(
            id: input.utterance.sourceSegmentID,
            sequence: presentationSequence,
            sourceSegmentSequence: input.sourceSegmentSequence,
            rawSourceText: input.sourceAudit.rawText,
            sourceText: input.utterance.text,
            sourceCorrections: input.sourceAudit.corrections,
            sourcePronounDecisions: input.sourceAudit.pronounDecisions,
            targetText: "",
            startedMilliseconds: milliseconds(input.utterance.startedAt),
            endedMilliseconds: milliseconds(input.utterance.endedAt),
            translationMilliseconds: 0
        )
    }

    private func milliseconds(_ duration: Duration) -> Int64 {
        let parts = duration.components
        let seconds = parts.seconds.multipliedReportingOverflow(by: 1_000).partialValue
        return seconds + Int64(parts.attoseconds / 1_000_000_000_000_000)
    }
}
