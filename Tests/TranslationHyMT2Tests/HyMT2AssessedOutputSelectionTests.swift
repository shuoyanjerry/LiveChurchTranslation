import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2AssessedOutputSelectionTests {
    @Test func completeCandidateOutranksShorterCandidateWithFewerWarnings() {
        let complete = reviewed(
            target: "The whole sermon remains available to listeners.",
            issueCodes: ["quality.missing_number", "quality.missing_required_term"]
        )
        let truncated = reviewed(
            target: "The sermon.",
            issueCodes: ["quality.implausible_length"]
        )

        #expect(complete.preferredBestEffort(over: truncated) == complete)
        #expect(truncated.preferredBestEffort(over: complete) == complete)
    }

    @Test func warningCountBreaksTieWhenBothCandidatesArePlausible() {
        let stronger = reviewed(
            target: "The complete translation.",
            issueCodes: ["quality.missing_number"]
        )
        let weaker = reviewed(
            target: "Another complete translation.",
            issueCodes: ["quality.missing_number", "quality.missing_required_term"]
        )

        #expect(stronger.preferredBestEffort(over: weaker) == stronger)
    }

    private func reviewed(
        target: String,
        issueCodes: [String]
    ) -> HyMT2AssessedOutput {
        HyMT2AssessedOutput(
            target: target,
            review: TranslationReview(issueCodes: issueCodes),
            validationIssueCount: issueCodes.count
        )
    }
}
