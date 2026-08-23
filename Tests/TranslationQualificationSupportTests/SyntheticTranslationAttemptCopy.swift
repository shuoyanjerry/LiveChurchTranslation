import TranslationQualificationSupport

enum SyntheticTranslationAttemptCopy {
    static func make(
        _ base: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment,
        status: TranslationQualificationAttemptStatus? = nil,
        translationSource: String? = nil,
        outcomes: [String]? = nil,
        attemptCount: Int? = nil,
        strictRetryUsed: Bool? = nil,
        glossaryTerms: [TranslationQualificationTermResult]? = nil,
        preservationChecks: [TranslationQualificationCheck]? = nil,
        pronounResults: [TranslationQualificationPronounResult]? = nil
    ) -> TranslationQualificationAttempt {
        let finalStatus = status ?? base.status
        let finalOutcomes = outcomes ?? base.completionOutcomes
        return TranslationQualificationAttempt(
            segment: segment,
            status: finalStatus,
            hypothesisEnglish: finalStatus == .success
                ? (base.hypothesisEnglish ?? "Synthetic translation") : nil,
            translationSourceText: translationSource ?? base.translationSourceText,
            contextSegmentIDs: base.contextSegmentIDs,
            strictRetryUsed: strictRetryUsed ?? (finalOutcomes.count == 2),
            completionAttemptCount: attemptCount ?? finalOutcomes.count,
            completionOutcomes: finalOutcomes,
            latencySeconds: base.latencySeconds,
            failureCode: finalStatus == .failure ? "synthetic.failure" : nil,
            glossaryTerms: glossaryTerms ?? base.glossaryTerms,
            preservationChecks: preservationChecks ?? base.preservationChecks,
            pronounResults: pronounResults ?? base.pronounResults
        )
    }
}
