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

    @Test func freshCandidateAlwaysOutranksDetectedContextReplay() {
        let replay = reviewed(
            target: "A stale translation from the preceding segment.",
            issueCodes: ["quality.context_replay"]
        )
        let fresh = reviewed(
            target: "A complete translation of the current segment.",
            issueCodes: ["quality.missing_required_term", "quality.missing_number"]
        )

        #expect(fresh.preferredBestEffort(over: replay) == fresh)
        #expect(replay.preferredBestEffort(over: fresh) == fresh)
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
