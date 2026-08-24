import Testing
import TranslationQualificationSupport

@Suite struct SafetyFallbackCompletionPolicyTests {
    @Test func acceptsMandatoryPronounReviewAlongsideOtherQualityWarnings() throws {
        let values = try fixtureValues()
        let outcomes = [
            "initial.validationRejected",
            "strictRetry.validationRejected",
            "safetyFallback.accepted",
        ]
        let reviewed = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            outcomes: outcomes,
            backendReviewIssueCodes: [
                "quality.missing_negation", "quality.pronoun_alignment",
            ]
        )
        let wrongReview = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            outcomes: outcomes,
            backendReviewIssueCodes: ["quality.validation_failed"]
        )

        try TranslationQualificationCompletionPolicy.validate(reviewed)
        #expect(reviewed.safetyFallbackUsed == true)
        #expect(!TranslationQualificationCompletionPolicy.approvesContext(reviewed))
        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationCompletionPolicy.validate(wrongReview)
        }
    }

    @Test func acceptsTerminalRejectionAsProviderFailure() throws {
        let values = try fixtureValues()
        let failed = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            status: .failure,
            outcomes: [
                "initial.validationRejected",
                "strictRetry.validationRejected",
                "safetyFallback.validationRejected",
            ]
        )

        try TranslationQualificationCompletionPolicy.validate(failed)
        #expect(failed.safetyFallbackUsed == true)
        #expect(!TranslationQualificationCompletionPolicy.approvesContext(failed))
    }

    private func fixtureValues() throws -> (
        segment: TranslationQualificationSegment,
        attempt: TranslationQualificationAttempt
    ) {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        return (corpus.manifest.segments[1], report.attempts[1])
    }
}
