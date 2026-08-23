import ASRAPI
import DiscourseResolutionAPI
import GlossaryAPI
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
            return recognizedInputs(
                recognition,
                segment: segment,
                glossary: enabled,
                discourseContext: discourseContext
            )
        } catch let failure as UtteranceProcessingFailure {
            throw failure
        } catch ASRError.filteredNonspeech {
            throw IgnoredUtterance(message: ASRError.filteredNonspeech.localizedDescription)
        } catch ASRError.promptOnlyHallucination {
            throw IgnoredUtterance(message: ASRError.promptOnlyHallucination.localizedDescription)
        } catch {
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
        return RecognizedSentenceSplitter.split(
            resolved,
            languageCode: mode.sourceRecognitionCode
        ).map {
            RecognizedInput(
                utterance: $0.utterance,
                sourceSegmentSequence: segment.sequenceNumber,
                glossary: glossary,
                sourceAudit: $0.audit,
                pronounGuidance: $0.pronounGuidance,
                isFinalInSourceSegment: $0.isFinalInSourceSegment,
                sourceDiscourseText: $0.sourceDiscourseText
            )
        }
    }
}
