import Foundation
import TranslationQualificationSupport

struct HyMTAdjudicationReviewEvidence {
    let registryURL: URL
    let settlementURL: URL
    let registrySnapshot: HyMTQualificationPrivateSnapshot
    let settlementSnapshot: HyMTQualificationPrivateSnapshot
    let registry: TranslationHumanReviewerRegistry

    static func load(
        _ input: HyMTAdjudicationConfiguration,
        reviewPacketSHA256: String
    ) throws -> Self {
        let registrySnapshot = try HyMTQualificationPrivateFile.snapshot(
            at: input.reviewerRegistryURL,
            maximumByteCount: 1_024 * 1_024
        )
        let registry = try TranslationHumanReviewEvidence.decodeProductionReviewerRegistry(
            from: registrySnapshot.data
        )
        let settlementSnapshot = try HyMTQualificationPrivateFile.snapshot(
            at: input.humanReviewSidecarURL,
            maximumByteCount: 16 * 1_024 * 1_024
        )
        let settlement = try TranslationHumanReviewEvidence.decodeSettlement(
            from: settlementSnapshot.data
        )
        guard settlement.reviewPacketSHA256 == reviewPacketSHA256,
            settlement.reviewerRegistrySHA256 == registrySnapshot.sha256
        else { throw invalid }
        return Self(
            registryURL: input.reviewerRegistryURL,
            settlementURL: input.humanReviewSidecarURL,
            registrySnapshot: registrySnapshot,
            settlementSnapshot: settlementSnapshot,
            registry: registry
        )
    }

    func requireUnchanged() throws {
        _ = try HyMTQualificationPrivateFile.read(
            at: registryURL,
            expectedSHA256: registrySnapshot.sha256,
            maximumByteCount: 1_024 * 1_024
        )
        _ = try HyMTQualificationPrivateFile.read(
            at: settlementURL,
            expectedSHA256: settlementSnapshot.sha256,
            maximumByteCount: 16 * 1_024 * 1_024
        )
    }

    private static var invalid: TranslationQualificationError {
        .invalidReport("signed human review evidence is inconsistent")
    }
}
