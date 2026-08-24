import ASRAPI
import DiscourseResolutionAPI
import Foundation
import GlossaryAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

extension UtteranceProcessor {
    func recognize(_ segment: SpeechSegment) async throws -> [RecognizedInput] {
        try await recognize(segment, discourseContext: discourseContext.entries)
    }

    func recognize(
        _ segment: SpeechSegment,
        discourseContext: [VerifiedDiscourseTurn]
    ) async throws -> [RecognizedInput] {
        do {
            let glossary = try await dependencies.glossary.snapshot()
            let enabled = glossary.entries.filter(\.isEnabled)
            let recognition = try await dependencies.asr.transcribe(
                ASRRequest(
                    segment: segment,
                    languageCode: mode.sourceRecognitionCode,
                    contextPrompt: asrPrompt(from: enabled, mode: mode)
                )
            )
            let inputs = recognizedInputs(
                recognition,
                segment: segment,
                glossary: enabled,
                discourseContext: discourseContext
            )
            guard !inputs.isEmpty else {
                throw failure(stage: .recognition, error: ASRError.noProcessableSentences)
            }
            return inputs
        } catch let failure as UtteranceProcessingFailure {
            throw failure
        } catch let classified as any ASRFailureImpactProviding {
            throw failure(stage: .recognition, error: classified)
        } catch {
            if error is CancellationError { throw CancellationError() }
            throw failure(stage: .recognition, error: error)
        }
    }

    private func recognizedInputs(
        _ recognition: RecognizedUtterance,
        segment: SpeechSegment,
        glossary: [GlossaryEntry],
        discourseContext: [VerifiedDiscourseTurn]
    ) -> [RecognizedInput] {
        let normalized = normalizedRecognition(recognition, entries: glossary, mode: mode)
        let resolved = resolvedRecognition(
            normalized,
            sequence: Int(clamping: segment.sequenceNumber),
            context: discourseContext
        )
        recordRecognitionAfterCriticalPath(
            resolved.utterance,
            original: recognition,
            segment: segment
        )
        guard !resolved.utterance.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        return [
            RecognizedInput(
                utterance: resolved.utterance,
                sourceSegmentSequence: segment.sequenceNumber,
                glossary: glossary,
                sourceAudit: resolved.audit,
                pronounGuidance: resolved.pronounGuidance,
                isFinalInSourceSegment: true,
                sourceDiscourseText: resolved.utterance.text
            )
        ]
    }

    /// Keeps recovery compatible with records that were partially persisted by a
    /// release that translated one recognized segment as multiple sentence entries.
    func legacyRecoveryInputs(for inputs: [RecognizedInput]) -> [RecognizedInput] {
        guard inputs.count == 1, let input = inputs.first else { return inputs }

        let slices = RecognizedSentenceSplitter.split(
            ResolvedDiscourseUtterance(
                utterance: input.utterance,
                audit: input.sourceAudit,
                pronounGuidance: input.pronounGuidance
            ),
            languageCode: mode.sourceRecognitionCode
        )
        return slices.map {
            RecognizedInput(
                utterance: $0.utterance,
                sourceSegmentSequence: input.sourceSegmentSequence,
                glossary: input.glossary,
                sourceAudit: $0.audit,
                pronounGuidance: $0.pronounGuidance,
                isFinalInSourceSegment: $0.isFinalInSourceSegment,
                sourceDiscourseText: $0.sourceDiscourseText
            )
        }
    }

    func recoveryInputs(
        for inputs: [RecognizedInput],
        record: PendingUtteranceRecord,
        persistedEntries: [TranscriptEntry]
    ) throws -> [RecognizedInput] {
        guard record.processingTopology == .unversionedV1 else { return inputs }
        let legacyInputs = legacyRecoveryInputs(for: inputs)
        let compatibleIDs = Set(legacyInputs.map(\.utterance.sourceSegmentID))
        let segmentEntries = persistedEntries.filter {
            $0.sourceSegmentSequence == record.id.sequenceNumber
                || compatibleIDs.contains($0.id)
        }
        guard !segmentEntries.isEmpty else {
            // With no partial output, an atomic replay cannot duplicate or omit
            // content that a previous release already displayed.
            return inputs
        }
        if segmentEntries.contains(where: { $0.id != record.segment.id }) {
            return legacyInputs
        }
        guard
            segmentEntries.count == 1,
            let rootEntry = segmentEntries.first,
            rootEntry.id == record.segment.id
        else {
            throw ambiguousRecoveryTopology()
        }
        let segmentStart = milliseconds(record.segment.startedAt)
        let segmentEnd = milliseconds(record.segment.endedAt)
        let beginsAtOrBeforeSegment = rootEntry.startedMilliseconds <= segmentStart
        if beginsAtOrBeforeSegment && rootEntry.endedMilliseconds >= segmentEnd {
            return inputs
        }
        if beginsAtOrBeforeSegment && rootEntry.endedMilliseconds < segmentEnd {
            return legacyInputs
        }
        throw ambiguousRecoveryTopology()
    }

    private func ambiguousRecoveryTopology() -> UtteranceProcessingFailure {
        UtteranceProcessingFailure(
            stage: .persistence,
            code: "recovery.topology_ambiguous",
            message: "旧版待恢复片段无法安全判定处理方式，原始录音已保留。",
            pendingEntry: nil,
            impact: .pipeline
        )
    }

    private func milliseconds(_ duration: Duration) -> Int64 {
        let parts = duration.components
        let seconds = parts.seconds.multipliedReportingOverflow(by: 1_000).partialValue
        return seconds + Int64(parts.attoseconds / 1_000_000_000_000_000)
    }
}
