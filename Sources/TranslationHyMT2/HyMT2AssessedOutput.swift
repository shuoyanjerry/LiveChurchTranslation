import TranslationAPI

struct HyMT2AssessedOutput: Equatable, Sendable {
    let target: String
    let review: TranslationReview?
    let validationIssueCount: Int

    func preferredBestEffort(over previous: HyMT2AssessedOutput) -> HyMT2AssessedOutput {
        if hasImplausibleLengthIssue != previous.hasImplausibleLengthIssue {
            return hasImplausibleLengthIssue ? previous : self
        }
        return validationIssueCount <= previous.validationIssueCount ? self : previous
    }

    static func approved(
        target: String
    ) -> HyMT2AssessedOutput {
        HyMT2AssessedOutput(
            target: target,
            review: nil,
            validationIssueCount: 0
        )
    }

    static func pronounSafetyFallback(
        target: String,
        reviewIssueCodes: [String] = [],
        validationIssueCount: Int = 0
    ) -> HyMT2AssessedOutput {
        let issueCodes = Array(
            Set(reviewIssueCodes + ["quality.pronoun_alignment"])
        ).sorted()
        return HyMT2AssessedOutput(
            target: target,
            review: TranslationReview(issueCodes: issueCodes),
            validationIssueCount: validationIssueCount + 1
        )
    }

    private var hasImplausibleLengthIssue: Bool {
        review?.issueCodes.contains("quality.implausible_length") == true
    }
}
