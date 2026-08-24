import CryptoKit
import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct FreezeEvidenceTests {
    @Test func trustedRootVerifiesExactCanonicalFreeze() throws {
        let fixture = try signedFreeze()
        let policy = TranslationFreezeTrustPolicy(
            policyRevision: TranslationQualificationFreezeStatement.currentPolicyRevision,
            authorityPublicKeysByID: [fixture.keyID: fixture.publicKeyBase64]
        )

        let verified = try TranslationQualificationFreezeVerifier.verify(
            fixture.data,
            trustPolicy: policy
        )

        #expect(verified.statement == fixture.envelope.statement)
        #expect(verified.authorityKeyID == fixture.keyID)
        #expect(
            verified.attestationFileSHA256
                == TranslationQualificationSHA256.hash(data: fixture.data)
        )
    }

    @Test func callerCreatedRootCannotSatisfyEmptyProductionPolicy() throws {
        let fixture = try signedFreeze()
        let production = TranslationFreezeTrustPolicy(
            policyRevision: TranslationQualificationFreezeStatement.currentPolicyRevision,
            authorityPublicKeysByID: [:]
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationFreezeVerifier.verify(
                fixture.data,
                trustPolicy: production
            )
        }
    }

    @Test func changedStatementCannotReuseAuthoritySignature() throws {
        let fixture = try signedFreeze()
        var object = try #require(
            JSONSerialization.jsonObject(with: fixture.data) as? [String: Any]
        )
        var statement = try #require(object["statement"] as? [String: Any])
        statement["reportFileSHA256"] = String(repeating: "f", count: 64)
        object["statement"] = statement
        let changed = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let policy = TranslationFreezeTrustPolicy(
            policyRevision: TranslationQualificationFreezeStatement.currentPolicyRevision,
            authorityPublicKeysByID: [fixture.keyID: fixture.publicKeyBase64]
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationFreezeVerifier.verify(changed, trustPolicy: policy)
        }
    }

    @Test func duplicateAndNoncanonicalFreezeJSONFailClosed() throws {
        let fixture = try signedFreeze()
        let policy = TranslationFreezeTrustPolicy(
            policyRevision: TranslationQualificationFreezeStatement.currentPolicyRevision,
            authorityPublicKeysByID: [fixture.keyID: fixture.publicKeyBase64]
        )
        let text = try #require(String(data: fixture.data, encoding: .utf8))
        let duplicate = Data(
            text.replacingOccurrences(of: "{", with: "{\"schemaVersion\":1,", maxReplacements: 1)
                .utf8
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationFreezeVerifier.verify(duplicate, trustPolicy: policy)
        }
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationFreezeVerifier.verify(
                Data((text + "\n").utf8),
                trustPolicy: policy
            )
        }
    }

    private func signedFreeze() throws -> FreezeFixture {
        let values = try releaseValues()
        let statement = try TranslationQualificationFreezeEvidence.makeStatement(
            report: values.report,
            artifacts: artifacts(),
            frozenAt: "2026-08-24T12:00:00Z",
            requestID: "62EA4E1B-1EB4-40B9-86D0-08C7417DE6DF"
        )
        let key = Curve25519.Signing.PrivateKey()
        let publicKeyBase64 = key.publicKey.rawRepresentation.base64EncodedString()
        let keyID = try TranslationQualificationFreezeEvidence.authorityKeyID(
            forPublicKeyBase64: publicKeyBase64
        )
        let payload = try TranslationQualificationFreezeEvidence.signingPayload(
            statement: statement,
            authorityKeyID: keyID
        )
        let envelope = TranslationQualificationSignedFreeze(
            statement: statement,
            authorityKeyID: keyID,
            signatureBase64: try key.signature(for: payload).base64EncodedString()
        )
        return FreezeFixture(
            data: try TranslationQualificationFreezeEvidence.encodeSignedFreeze(envelope),
            envelope: envelope,
            keyID: keyID,
            publicKeyBase64: publicKeyBase64
        )
    }

    private func sha(_ character: Character) -> String {
        String(repeating: character, count: 64)
    }

    private func artifacts() -> TranslationFreezeArtifactIdentity {
        TranslationFreezeArtifactIdentity(
            reportFilename: "report.json",
            reportSHA256: sha("1"),
            postflightFilename: "report.json.postflight.json",
            postflightSHA256: sha("2"),
            reviewPacketFilename: "report.review-packet.json",
            reviewPacketSHA256: sha("3")
        )
    }
}

private struct FreezeFixture {
    let data: Data
    let envelope: TranslationQualificationSignedFreeze
    let keyID: String
    let publicKeyBase64: String
}

extension String {
    fileprivate func replacingOccurrences(
        of target: String,
        with replacement: String,
        maxReplacements: Int
    ) -> String {
        guard maxReplacements > 0, let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
