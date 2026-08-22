import ASRAPI
import DiscourseResolutionAPI
import TranscriptAPI

extension UtteranceProcessor {
    func resolveDiscourse(
        _ normalized: (utterance: RecognizedUtterance, audit: TranscriptSourceAudit),
        sequence: Int,
        context: [VerifiedDiscourseTurn]
    ) -> (utterance: RecognizedUtterance, audit: TranscriptSourceAudit) {
        let result = dependencies.discourseResolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: sequence,
                currentText: normalized.utterance.text,
                verifiedTurns: context
            )
        )
        guard result.resolvedText != normalized.utterance.text else { return normalized }
        return (
            replacingText(in: normalized.utterance, with: result.resolvedText),
            TranscriptSourceAudit(
                rawText: normalized.audit.rawText,
                corrections: normalized.audit.corrections + result.corrections.map(auditCorrection)
            )
        )
    }

    private func replacingText(
        in utterance: RecognizedUtterance,
        with text: String
    ) -> RecognizedUtterance {
        RecognizedUtterance(
            id: utterance.id,
            sourceSegmentID: utterance.sourceSegmentID,
            rawText: utterance.rawText,
            text: text,
            confidence: utterance.confidence,
            startedAt: utterance.startedAt,
            endedAt: utterance.endedAt
        )
    }

    private func auditCorrection(
        _ correction: DiscourseCorrection
    ) -> TranscriptSourceCorrection {
        TranscriptSourceCorrection(
            observedText: correction.original,
            replacementText: correction.replacement,
            kind: .discoursePronoun,
            reason: correction.reason.rawValue,
            confidence: correction.confidence,
            evidenceSequence: correction.evidence.sequence,
            evidenceText: correction.evidence.text,
            utf16Location: correction.range.location,
            utf16Length: correction.range.length
        )
    }
}
