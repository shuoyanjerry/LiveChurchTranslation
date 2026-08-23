import TranslationAPI

struct HyMT2AssessedOutput: Equatable, Sendable {
    let target: String
    let review: TranslationReview?
    let validationIssueCount: Int

    static func approved(
        target: String
    ) -> HyMT2AssessedOutput {
        HyMT2AssessedOutput(
            target: target,
            review: nil,
            validationIssueCount: 0
        )
    }
}
