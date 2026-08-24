import DiscourseResolutionAPI
import TranslationAPI
import TranslationQualificationSupport

extension HyMTQualificationRunner {
    func attemptInput(
        segment: TranslationQualificationSegment,
        recent: [HyMTQualificationPersistedTurn],
        resolution: DiscourseResolutionResult,
        evaluation: HyMTQualificationAttemptEvaluation
    ) async -> HyMTQualificationAttemptInput {
        let summary = await recorder.takeSummary(for: evaluation.request.id)
        let traces = await pronounTraceRecorder.take(for: evaluation.request.id)
        let guidance = HyMTQualificationGuidanceMapper.translationGuidance(
            resolution.pronounGuidance
        )
        let mapping = HyMTQualificationTraceMapper.map(
            segment: segment,
            guidance: guidance,
            traces: traces,
            summary: summary,
            hasHypothesis: evaluation.outcome.hypothesis != nil
        )
        return HyMTQualificationAttemptInput(
            segment: segment,
            translationSource: resolution.resolvedText,
            contextIDs: recent.segmentIDs,
            guidance: resolution.pronounGuidance,
            realizationObservations: mapping.observations,
            traceIntegrityCheck: mapping.integrityCheck,
            termExpectations: evaluation.termExpectations,
            hypothesis: evaluation.outcome.hypothesis,
            backendReviewIssueCodes: evaluation.outcome.backendReviewIssueCodes,
            summary: summary,
            latencySeconds: evaluation.outcome.latencySeconds,
            error: evaluation.outcome.error
        )
    }

    func termExpectations(
        for request: TranslationRequest,
        segment: TranslationQualificationSegment
    ) throws -> [TranslationQualificationTermExpectation] {
        try HyMTQualificationGlossary.evidenceExpectations(
            source: request.sourceText,
            matchedTerms: request.glossary,
            manifestTerms: segment.theologyTerms,
            limit: maximumGlossaryTerms
        )
    }
}

struct HyMTQualificationAttemptEvaluation {
    let request: TranslationRequest
    let termExpectations: [TranslationQualificationTermExpectation]
    let outcome: HyMTQualificationOutcome
}
