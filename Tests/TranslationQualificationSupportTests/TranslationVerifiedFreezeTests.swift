import CryptoKit
import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationVerifiedFreezeTests {
    @Test func exactPacketRebuiltFromSignedReportIsAccepted() throws {
        let fixture = try makeFixture()

        try fixture.verified.validateReviewPacket(
            fixture.packetData,
            report: fixture.values.report,
            corpus: fixture.values.expectation.corpus,
            files: fixture.files
        )
    }

    @Test func rootSignedButMisrepresentedPacketContentIsRejected() throws {
        let base = try makePacketFixture()
        var object = try #require(
            JSONSerialization.jsonObject(with: base.packetData) as? [String: Any]
        )
        var items = try #require(object["items"] as? [[String: Any]])
        items[0]["sourceText"] = "被调包的审核内容"
        object["items"] = items
        let tamperedData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        let tamperedSHA = TranslationQualificationSHA256.hash(data: tamperedData)
        let verified = try signedFreeze(
            report: base.values.report,
            packetSHA256: tamperedSHA
        )
        let files = evidenceFiles(packetSHA256: tamperedSHA)

        #expect(throws: TranslationQualificationError.self) {
            try verified.validateReviewPacket(
                tamperedData,
                report: base.values.report,
                corpus: base.values.expectation.corpus,
                files: files
            )
        }
    }

    @Test func reportAttemptCannotChangeAfterFreezeSignature() throws {
        let fixture = try makeFixture()
        let changed = try report(fixture.values.report) { object in
            var attempts = try #require(object["attempts"] as? [[String: Any]])
            attempts[0]["hypothesisEnglish"] = "Tampered after freeze"
            object["attempts"] = attempts
        }
        let registrySHA = try #require(
            fixture.values.expectation.trustedHumanReviewerRegistrySHA256
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try fixture.verified.releaseExpectation(
                report: changed,
                corpus: fixture.values.expectation.corpus,
                files: fixture.files,
                trustedHumanReviewers: fixture.values.expectation.trustedHumanReviewers,
                reviewerRegistrySHA256: registrySHA
            )
        }
    }
}

extension TranslationVerifiedFreezeTests {
    private func makeFixture() throws -> VerifiedFreezeFixture {
        let base = try makePacketFixture()
        let packetSHA = TranslationQualificationSHA256.hash(data: base.packetData)
        return VerifiedFreezeFixture(
            values: base.values,
            packetData: base.packetData,
            files: evidenceFiles(packetSHA256: packetSHA),
            verified: try signedFreeze(report: base.values.report, packetSHA256: packetSHA)
        )
    }

    private func makePacketFixture() throws -> (
        values: TranslationReleaseValues,
        packetData: Data
    ) {
        let values = try releaseValues()
        let packet = try TranslationHumanReviewEvidence.makeReviewPacket(
            report: values.report,
            expectation: values.expectation,
            reportFileSHA256: sha("1"),
            postflightFileSHA256: sha("2")
        )
        return (values, try TranslationHumanReviewEvidence.encodeReviewPacket(packet))
    }

    private func signedFreeze(
        report: TranslationQualificationReport,
        packetSHA256: String
    ) throws -> TranslationVerifiedFreeze {
        let statement = try TranslationQualificationFreezeEvidence.makeStatement(
            report: report,
            artifacts: evidenceIdentity(packetSHA256: packetSHA256),
            frozenAt: "2026-08-24T12:00:00Z",
            requestID: "B228B703-5A1C-4221-A39C-BC2FFB467B9F"
        )
        let key = Curve25519.Signing.PrivateKey()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        let keyID = try TranslationQualificationFreezeEvidence.authorityKeyID(
            forPublicKeyBase64: publicKey
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
        let data = try TranslationQualificationFreezeEvidence.encodeSignedFreeze(envelope)
        return try TranslationQualificationFreezeVerifier.verify(
            data,
            trustPolicy: TranslationFreezeTrustPolicy(
                policyRevision: statement.policyRevision,
                authorityPublicKeysByID: [keyID: publicKey]
            )
        )
    }

    private func evidenceFiles(packetSHA256: String) -> TranslationFrozenEvidenceFiles {
        TranslationFrozenEvidenceFiles(
            reportFilename: "report.json",
            reportFileSHA256: sha("1"),
            postflightFilename: "report.json.postflight.json",
            postflightFileSHA256: sha("2"),
            reviewPacketFilename: "report.review-packet.json",
            reviewPacketSHA256: packetSHA256
        )
    }

    private func evidenceIdentity(packetSHA256: String) -> TranslationFreezeArtifactIdentity {
        TranslationFreezeArtifactIdentity(
            reportFilename: "report.json",
            reportSHA256: sha("1"),
            postflightFilename: "report.json.postflight.json",
            postflightSHA256: sha("2"),
            reviewPacketFilename: "report.review-packet.json",
            reviewPacketSHA256: packetSHA256
        )
    }

    private func sha(_ character: Character) -> String {
        String(repeating: character, count: 64)
    }
}

private struct VerifiedFreezeFixture {
    let values: TranslationReleaseValues
    let packetData: Data
    let files: TranslationFrozenEvidenceFiles
    let verified: TranslationVerifiedFreeze
}
