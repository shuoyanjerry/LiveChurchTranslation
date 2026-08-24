import CryptoKit
import Foundation

enum HumanReviewerRegistryValidator {
    static func validateEnvelope(
        _ registry: TranslationHumanReviewerRegistry
    ) throws {
        let reviewerIDs = registry.reviewers.map(\.reviewerID)
        guard
            registry.schemaVersion == TranslationHumanReviewerRegistry.currentSchemaVersion,
            registry.policyRevision == TranslationHumanReviewEvidence.currentPolicyRevision,
            validRegistryID(registry.registryID),
            registry.registryRevision > 0,
            validRootKeyID(registry.rootKeyID),
            HumanReviewSignatureValidator.validTrustedReviewers(registry.reviewers),
            reviewerIDs == reviewerIDs.sorted(),
            canonicalBase64(registry.signatureBase64, byteCount: 64) != nil
        else { throw invalid }
    }

    static func verify(
        _ registry: TranslationHumanReviewerRegistry,
        trustPolicy: HumanReviewerRegistryTrustPolicy
    ) throws {
        guard validTrustPolicy(trustPolicy),
            registry.policyRevision == trustPolicy.policyRevision,
            registry.registryID == trustPolicy.registryID,
            registry.registryRevision == trustPolicy.registryRevision,
            let publicKeyValue = trustPolicy.rootPublicKeysByID[registry.rootKeyID],
            registry.rootKeyID
                == (try? TranslationHumanReviewEvidence.reviewerRegistryRootKeyID(
                    forPublicKeyBase64: publicKeyValue
                )),
            let keyData = canonicalBase64(publicKeyValue, byteCount: 32),
            let signature = canonicalBase64(registry.signatureBase64, byteCount: 64),
            let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
            let payload = try? TranslationHumanReviewEvidence.reviewerRegistrySigningPayload(
                for: registry
            ),
            publicKey.isValidSignature(signature, for: payload)
        else { throw invalid }
    }

    private static func validTrustPolicy(
        _ policy: HumanReviewerRegistryTrustPolicy
    ) -> Bool {
        guard policy.policyRevision == TranslationHumanReviewEvidence.currentPolicyRevision,
            validRegistryID(policy.registryID), policy.registryRevision > 0
        else { return false }
        return policy.rootPublicKeysByID.allSatisfy { keyID, publicKey in
            keyID
                == (try? TranslationHumanReviewEvidence.reviewerRegistryRootKeyID(
                    forPublicKeyBase64: publicKey
                ))
        }
    }

    private static func validRegistryID(_ value: String) -> Bool {
        (1...128).contains(value.utf8.count)
            && value.utf8.allSatisfy {
                (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46
            }
    }

    private static func validRootKeyID(_ value: String) -> Bool {
        let prefix = "registry-root-"
        return value.hasPrefix(prefix)
            && TranslationProvenanceValidator.isSHA(String(value.dropFirst(prefix.count)))
    }

    private static func canonicalBase64(
        _ value: String,
        byteCount: Int
    ) -> Data? {
        guard let data = Data(base64Encoded: value), data.count == byteCount,
            data.base64EncodedString() == value
        else { return nil }
        return data
    }

    private static var invalid: TranslationQualificationError {
        .invalidReport("human reviewer registry is invalid")
    }
}

extension TranslationHumanReviewEvidence {
    public static func reviewerRegistryRootKeyID(
        forPublicKeyBase64 value: String
    ) throws -> String {
        guard let data = Data(base64Encoded: value), data.count == 32,
            data.base64EncodedString() == value
        else { throw TranslationQualificationError.invalidReport("registry root key is invalid") }
        return "registry-root-" + TranslationQualificationSHA256.hash(data: data)
    }

    public static func reviewerRegistrySigningPayload(
        for registry: TranslationHumanReviewerRegistry
    ) throws -> Data {
        try HumanReviewerRegistryValidator.validateEnvelope(registry)
        return try canonicalData(
            ReviewerRegistrySignedPayload(
                domain: "LIVE-CHURCH-TRANSLATION-REVIEWER-REGISTRY-V2",
                schemaVersion: registry.schemaVersion,
                policyRevision: registry.policyRevision,
                registryID: registry.registryID,
                registryRevision: registry.registryRevision,
                rootKeyID: registry.rootKeyID,
                reviewers: registry.reviewers
            )
        )
    }
}

private struct ReviewerRegistrySignedPayload: Encodable {
    let domain: String
    let schemaVersion: Int
    let policyRevision: String
    let registryID: String
    let registryRevision: Int
    let rootKeyID: String
    let reviewers: [TranslationHumanReviewerIdentity]
}
