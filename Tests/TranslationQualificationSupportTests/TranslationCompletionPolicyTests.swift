import Testing
import TranslationQualificationSupport

@Suite struct TranslationCompletionPolicyTests {
    @Test func acceptsOnlyCanonicalSuccessAndFailureTransitions() throws {
        let values = try fixtureValues()
        let valid: [(TranslationQualificationAttemptStatus, [String])] = [
            (.success, ["initial.accepted"]),
            (.success, ["initial.validationRejected", "strictRetry.accepted"]),
            (.failure, []),
            (.failure, ["initial.transportFailed"]),
            (.failure, ["initial.validationRejected", "strictRetry.validationRejected"]),
            (.failure, ["initial.validationRejected", "strictRetry.transportFailed"]),
        ]
        for (status, outcomes) in valid {
            let attempt = SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                status: status,
                outcomes: outcomes
            )
            try TranslationQualificationCompletionPolicy.validate(attempt)
            #expect(
                TranslationQualificationCompletionPolicy.approvesContext(attempt)
                    == (status == .success)
            )
        }
    }

    @Test func rejectsContradictoryOrOutOfOrderTransitions() throws {
        let values = try fixtureValues()
        let invalid: [(TranslationQualificationAttemptStatus, [String])] = [
            (.success, ["initial.transportFailed"]),
            (.failure, ["initial.accepted"]),
            (.success, ["strictRetry.accepted", "initial.validationRejected"]),
            (.failure, ["initial.validationRejected"]),
        ]
        for (status, outcomes) in invalid {
            let attempt = SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                status: status,
                outcomes: outcomes
            )
            #expect(throws: TranslationQualificationError.self) {
                try TranslationQualificationCompletionPolicy.validate(attempt)
            }
            #expect(!TranslationQualificationCompletionPolicy.approvesContext(attempt))
        }
    }

    @Test func rejectsCountAndRetryFlagDrift() throws {
        let values = try fixtureValues()
        let countDrift = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            attemptCount: 2
        )
        let retryDrift = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            strictRetryUsed: true
        )

        for attempt in [countDrift, retryDrift] {
            #expect(throws: TranslationQualificationError.self) {
                try TranslationQualificationCompletionPolicy.validate(attempt)
            }
        }
    }

    @Test func reviewedCompletionIsAProviderSuccessButNeverContext() throws {
        let values = try fixtureValues()
        let reviewed = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            outcomes: ["initial.validationRejected", "strictRetry.validationRejected"],
            backendReviewIssueCodes: ["quality.missing_required_term"]
        )

        try TranslationQualificationCompletionPolicy.validate(reviewed)
        #expect(reviewed.status == .success)
        #expect(reviewed.hypothesisEnglish != nil)
        #expect(!TranslationQualificationCompletionPolicy.approvesContext(reviewed))
    }

    @Test func rejectsReviewDispositionThatContradictsCompletionTransition() throws {
        let values = try fixtureValues()
        let missingCodes = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            outcomes: ["initial.validationRejected", "strictRetry.validationRejected"]
        )
        let codesOnApproved = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            backendReviewIssueCodes: ["quality.validation_failed"]
        )

        for attempt in [missingCodes, codesOnApproved] {
            #expect(throws: TranslationQualificationError.self) {
                try TranslationQualificationCompletionPolicy.validate(attempt)
            }
        }
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
