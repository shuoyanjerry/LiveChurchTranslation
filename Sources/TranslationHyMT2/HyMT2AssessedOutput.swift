import TranslationAPI

struct HyMT2AssessedOutput: Equatable, Sendable {
    let target: String
    let review: TranslationReview?
    let validationIssueCount: Int
    let pronounRealizations: [HyMT2PronounRealization]
    let reviewedPhase: HyMT2AttemptPhase?

    init(
        target: String,
        review: TranslationReview?,
        validationIssueCount: Int,
        pronounRealizations: [HyMT2PronounRealization] = [],
        reviewedPhase: HyMT2AttemptPhase? = nil
    ) {
        self.target = target
        self.review = review
        self.validationIssueCount = validationIssueCount
        self.pronounRealizations = pronounRealizations
        self.reviewedPhase = reviewedPhase
    }

    func preferredBestEffort(over previous: HyMT2AssessedOutput) -> HyMT2AssessedOutput {
        if hasContextReplayIssue != previous.hasContextReplayIssue {
            return hasContextReplayIssue ? previous : self
        }
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
            validationIssueCount: 0,
            pronounRealizations: [],
            reviewedPhase: nil
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
            validationIssueCount: validationIssueCount + 1,
            pronounRealizations: [],
            reviewedPhase: nil
        )
    }

    private var hasImplausibleLengthIssue: Bool {
        review?.issueCodes.contains("quality.implausible_length") == true
    }

    private var hasContextReplayIssue: Bool {
        review?.issueCodes.contains("quality.context_replay") == true
    }
}
