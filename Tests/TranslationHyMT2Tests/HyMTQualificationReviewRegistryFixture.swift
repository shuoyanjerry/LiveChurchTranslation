import CryptoKit
import Foundation
import TranslationQualificationSupport

extension HyMTQualificationReviewEvidenceTests {
    func signedRegistry() throws -> (
        registry: TranslationHumanReviewerRegistry,
        policy: HumanReviewerRegistryTrustPolicy
    ) {
        let rootKey = try Curve25519.Signing.PrivateKey(
            rawRepresentation: try data(hex: String(repeating: "03", count: 32))
        )
        let rootPublicKey = rootKey.publicKey.rawRepresentation.base64EncodedString()
        let rootKeyID = try TranslationHumanReviewEvidence.reviewerRegistryRootKeyID(
            forPublicKeyBase64: rootPublicKey
        )
        let reviewers = try reviewers().sorted { $0.reviewerID < $1.reviewerID }
        let unsigned = TranslationHumanReviewerRegistry(
            policyRevision: TranslationHumanReviewEvidence.currentPolicyRevision,
            registryID: "synthetic-hymt-reviewers",
            registryRevision: 1,
            rootKeyID: rootKeyID,
            reviewers: reviewers,
            signatureBase64: Data(repeating: 0, count: 64).base64EncodedString()
        )
        let payload = try TranslationHumanReviewEvidence.reviewerRegistrySigningPayload(
            for: unsigned
        )
        let registry = TranslationHumanReviewerRegistry(
            policyRevision: unsigned.policyRevision,
            registryID: unsigned.registryID,
            registryRevision: unsigned.registryRevision,
            rootKeyID: unsigned.rootKeyID,
            reviewers: unsigned.reviewers,
            signatureBase64: try rootKey.signature(for: payload).base64EncodedString()
        )
        let policy = HumanReviewerRegistryTrustPolicy(
            policyRevision: unsigned.policyRevision,
            registryID: unsigned.registryID,
            registryRevision: unsigned.registryRevision,
            rootPublicKeysByID: [rootKeyID: rootPublicKey]
        )
        return (registry, policy)
    }
}
