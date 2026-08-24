import Foundation
import Testing
import TranslationQualificationSupport

@Suite("HyMTQualificationAdjudicationTests")
struct HyMTAdjudicationTests {
    @Test(
        .enabled(
            if: ProcessInfo.processInfo.environment[
                HyMTAdjudicationConfiguration.environmentFlag
            ] == "1",
            "Requires a root-signed freeze and independently signed human review evidence."
        )
    )
    func gatesOnlyExternallyAttestedFrozenEvidence() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let configuration = try HyMTAdjudicationConfiguration.load(environment)
        else { return }
        let frozen = try HyMTAdjudicationFrozenEvidence.load(configuration)
        let review = try HyMTAdjudicationReviewEvidence.load(
            configuration,
            reviewPacketSHA256: frozen.files.reviewPacketSHA256
        )
        let expectation = try frozen.verifiedFreeze.releaseExpectation(
            report: frozen.report,
            corpus: frozen.corpus,
            files: frozen.files,
            trustedHumanReviewers: review.registry.reviewers,
            reviewerRegistrySHA256: review.registrySnapshot.sha256
        )
        try frozen.requireUnchanged()
        try review.requireUnchanged()
        try TranslationQualificationReleaseGate.requireAttestedReleaseReadyGates(
            frozen.report,
            expectation: expectation,
            humanReviewSidecar: review.settlementSnapshot.data
        )
        try frozen.requireUnchanged()
        try review.requireUnchanged()
        try HyMTAdjudicationOutput.printEvidence(
            frozen: frozen,
            review: review,
            expectation: expectation
        )
    }
}
