import TranslationQualificationSupport

extension NegationPolicyV2ShadowBuilder {
    static func collect(
        segments: [TranslationQualificationSegment],
        attempts: [TranslationQualificationAttempt]
    ) throws -> NegationPolicyV2ShadowDispositionSets {
        var allSource: [NegationPolicyV2Disposition] = []
        var successfulFull: [NegationPolicyV2Disposition] = []
        var failedSource: [NegationPolicyV2Disposition] = []
        for (segment, attempt) in zip(segments, attempts) {
            try validateIdentity(segment: segment, attempt: attempt)
            let source = NegationPolicyV2.sourceDisposition(attempt.translationSourceText)
            allSource.append(source)
            if attempt.status == .success {
                guard let hypothesis = attempt.hypothesisEnglish else {
                    throw NegationPolicyV2ShadowError.invalidInput
                }
                successfulFull.append(
                    NegationPolicyV2.disposition(
                        source: attempt.translationSourceText,
                        target: hypothesis
                    )
                )
            } else {
                guard attempt.hypothesisEnglish == nil else {
                    throw NegationPolicyV2ShadowError.invalidInput
                }
                failedSource.append(source)
            }
        }
        return NegationPolicyV2ShadowDispositionSets(
            allSource: allSource,
            successfulFull: successfulFull,
            failedSource: failedSource
        )
    }

    private static func validateIdentity(
        segment: TranslationQualificationSegment,
        attempt: TranslationQualificationAttempt
    ) throws {
        guard
            segment.id == attempt.segmentID,
            segment.sourceID == attempt.sourceID,
            segment.sequence == attempt.sequence
        else { throw NegationPolicyV2ShadowError.invalidInput }
    }
}
