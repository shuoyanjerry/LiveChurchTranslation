import DiscourseResolutionAPI
import TranslationAPI
import TranslationQualificationSupport

enum HyMTQualificationAttemptFactory {
    static func make(_ input: HyMTQualificationAttemptInput) -> TranslationQualificationAttempt {
        let translationGuidance = HyMTQualificationGuidanceMapper.translationGuidance(input.guidance)
        let observations = HyMTQualificationGuidanceMapper.observations(
            segment: input.segment,
            guidance: translationGuidance
        )
        let preservation = TranslationPreservationEvaluator.evaluate(
            segment: input.segment,
            hypothesis: input.hypothesis,
            terms: input.termExpectations
        )
        return TranslationQualificationAttempt(
            segment: input.segment,
            status: input.error == nil ? .success : .failure,
            hypothesisEnglish: input.hypothesis,
            translationSourceText: input.translationSource,
            contextSegmentIDs: input.contextIDs,
            strictRetryUsed: input.summary.strictRetryUsed,
            completionAttemptCount: input.summary.completionAttemptCount,
            completionOutcomes: input.summary.outcomes,
            latencySeconds: input.latencySeconds,
            failureCode: input.error.map(HyMTQualificationFailureCode.make),
            glossaryTerms: preservation.terms,
            preservationChecks: preservation.checks + [input.traceIntegrityCheck],
            pronounResults: TranslationPronounEvaluator.evaluate(
                occurrences: input.segment.pronounOccurrences,
                guidance: observations,
                realizations: input.realizationObservations,
                hypothesisAvailable: input.hypothesis != nil
            )
        )
    }
}

struct HyMTQualificationAttemptInput {
    let segment: TranslationQualificationSegment
    let translationSource: String
    let contextIDs: [String]
    let guidance: [DiscoursePronounGuidance]
    let realizationObservations: [TranslationPronounRealizationObservation]
    let traceIntegrityCheck: TranslationQualificationCheck
    let termExpectations: [TranslationQualificationTermExpectation]
    let hypothesis: String?
    let summary: HyMTQualificationAttemptSummary
    let latencySeconds: Double
    let error: (any Error)?
}
