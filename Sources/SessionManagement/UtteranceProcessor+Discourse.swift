import ASRAPI
import DiscourseResolutionAPI
import TranscriptAPI
import TranslationAPI

struct ResolvedDiscourseUtterance {
    let utterance: RecognizedUtterance
    let audit: TranscriptSourceAudit
    let pronounGuidance: [TranslationPronounGuidance]
}

extension UtteranceProcessor {
    func resolveDiscourse(
        _ normalized: (utterance: RecognizedUtterance, audit: TranscriptSourceAudit),
        sequence: Int,
        context: [VerifiedDiscourseTurn]
    ) -> ResolvedDiscourseUtterance {
        let result = dependencies.discourseResolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: sequence,
                currentText: normalized.utterance.text,
                verifiedTurns: context
            )
        )
        let guidance = result.pronounGuidance.map(translationGuidance)
        let audit = TranscriptSourceAudit(
            rawText: normalized.audit.rawText,
            corrections: normalized.audit.corrections + result.corrections.map(auditCorrection),
            pronounDecisions: normalized.audit.pronounDecisions
                + result.pronounGuidance.map(auditDecision)
        )
        guard result.resolvedText != normalized.utterance.text else {
            return ResolvedDiscourseUtterance(
                utterance: normalized.utterance,
                audit: audit,
                pronounGuidance: guidance
            )
        }
        return ResolvedDiscourseUtterance(
            utterance: replacingText(in: normalized.utterance, with: result.resolvedText),
            audit: audit,
            pronounGuidance: guidance
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

    private func translationGuidance(
        _ guidance: DiscoursePronounGuidance
    ) -> TranslationPronounGuidance {
        let resolution: TranslationPronounResolution
        switch guidance.resolution {
        case .unresolved:
            resolution = .unresolvedSpokenMandarin
        case .verified(let gender, _, _, _):
            resolution = gender == .female ? .verifiedFemale : .verifiedMale
        case .verifiedDeity:
            resolution = .verifiedDeity
        }
        return TranslationPronounGuidance(
            sourceRange: TranslationSourceRange(
                location: guidance.range.location,
                length: guidance.range.length
            ),
            resolution: resolution
        )
    }

    private func auditDecision(
        _ guidance: DiscoursePronounGuidance
    ) -> TranscriptSourcePronounDecision {
        switch guidance.resolution {
        case .unresolved:
            return TranscriptSourcePronounDecision(
                resolution: .unresolvedSpokenMandarin,
                utf16Location: guidance.range.location,
                utf16Length: guidance.range.length
            )
        case .verified(let gender, let reason, let confidence, let evidence):
            return TranscriptSourcePronounDecision(
                resolution: gender == .female ? .verifiedFemale : .verifiedMale,
                utf16Location: guidance.range.location,
                utf16Length: guidance.range.length,
                reason: reason.rawValue,
                confidence: confidence,
                evidenceSequence: evidence.sequence,
                evidenceText: evidence.text
            )
        case .verifiedDeity(let reason, let confidence, let evidence):
            return TranscriptSourcePronounDecision(
                resolution: .verifiedDeity,
                utf16Location: guidance.range.location,
                utf16Length: guidance.range.length,
                reason: reason.rawValue,
                confidence: confidence,
                evidenceSequence: evidence.sequence,
                evidenceText: evidence.text
            )
        }
    }
}
