import CryptoKit
import Foundation
import TranslationQualificationSupport

enum SyntheticHumanReviewerRegistryFactory {
    static func make(
        rootKey: Curve25519.Signing.PrivateKey,
        registryRevision: Int = 1,
        reviewers: [TranslationHumanReviewerIdentity]? = nil
    ) throws -> TranslationHumanReviewerRegistry {
        let rootKeyBase64 = rootKey.publicKey.rawRepresentation.base64EncodedString()
        let rootKeyID = try TranslationHumanReviewEvidence.reviewerRegistryRootKeyID(
            forPublicKeyBase64: rootKeyBase64
        )
        let reviewers = (reviewers ?? SyntheticHumanReviewSettlementFactory.trustedReviewers)
            .sorted { $0.reviewerID < $1.reviewerID }
        let unsigned = TranslationHumanReviewerRegistry(
            policyRevision: TranslationHumanReviewEvidence.currentPolicyRevision,
            registryID: registryID,
            registryRevision: registryRevision,
            rootKeyID: rootKeyID,
            reviewers: reviewers,
            signatureBase64: Data(repeating: 0, count: 64).base64EncodedString()
        )
        let payload = try TranslationHumanReviewEvidence.reviewerRegistrySigningPayload(
            for: unsigned
        )
        return TranslationHumanReviewerRegistry(
            policyRevision: unsigned.policyRevision,
            registryID: unsigned.registryID,
            registryRevision: unsigned.registryRevision,
            rootKeyID: unsigned.rootKeyID,
            reviewers: unsigned.reviewers,
            signatureBase64: try rootKey.signature(for: payload).base64EncodedString()
        )
    }

    static func policy(
        rootKey: Curve25519.Signing.PrivateKey,
        registryRevision: Int = 1
    ) throws -> HumanReviewerRegistryTrustPolicy {
        let publicKey = rootKey.publicKey.rawRepresentation.base64EncodedString()
        let rootKeyID = try TranslationHumanReviewEvidence.reviewerRegistryRootKeyID(
            forPublicKeyBase64: publicKey
        )
        return HumanReviewerRegistryTrustPolicy(
            policyRevision: TranslationHumanReviewEvidence.currentPolicyRevision,
            registryID: registryID,
            registryRevision: registryRevision,
            rootPublicKeysByID: [rootKeyID: publicKey]
        )
    }

    private static let registryID = "synthetic-reviewer-registry"
}
