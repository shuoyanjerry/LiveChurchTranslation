import CryptoKit
import Foundation

public enum TranslationQualificationFreezeVerifier {
    public static func verify(
        _ data: Data,
        trustPolicy: TranslationFreezeTrustPolicy
    ) throws -> TranslationVerifiedFreeze {
        let envelope: TranslationQualificationSignedFreeze =
            try TranslationQualificationFreezeEvidence.decodeCanonical(data)
        let statement = envelope.statement
        try TranslationQualificationFreezeEvidence.validate(statement)
        guard envelope.schemaVersion == TranslationQualificationSignedFreeze.currentSchemaVersion,
            statement.policyRevision == trustPolicy.policyRevision,
            let encodedKey = trustPolicy.authorityPublicKeysByID[envelope.authorityKeyID],
            try TranslationQualificationFreezeEvidence.authorityKeyID(
                forPublicKeyBase64: encodedKey
            ) == envelope.authorityKeyID,
            let keyData = canonicalBase64(encodedKey), keyData.count == 32,
            let signature = canonicalBase64(envelope.signatureBase64), signature.count == 64,
            let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
            let payload = try? TranslationQualificationFreezeEvidence.signingPayload(
                statement: statement,
                authorityKeyID: envelope.authorityKeyID
            ),
            key.isValidSignature(signature, for: payload)
        else { throw TranslationQualificationFreezeEvidence.invalid }
        return TranslationVerifiedFreeze(
            statement: statement,
            authorityKeyID: envelope.authorityKeyID,
            attestationFileSHA256: TranslationQualificationSHA256.hash(data: data)
        )
    }

    private static func canonicalBase64(_ value: String) -> Data? {
        guard let data = Data(base64Encoded: value), data.base64EncodedString() == value else {
            return nil
        }
        return data
    }
}
