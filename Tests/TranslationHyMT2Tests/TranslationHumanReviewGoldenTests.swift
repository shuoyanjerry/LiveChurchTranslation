import CryptoKit
import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct TranslationHumanReviewGoldenTests {
    @Test func fixedEd25519KeySignsFixedCanonicalPayload() throws {
        let privateKey = try Curve25519.Signing.PrivateKey(
            rawRepresentation: try Data(hex: privateKeyHex)
        )
        let publicKey = privateKey.publicKey.rawRepresentation
        let reviewerID = try TranslationHumanReviewEvidence.reviewerID(
            forPublicKeyBase64: publicKey.base64EncodedString()
        )
        let reviewer = TranslationHumanReviewerIdentity(
            reviewerID: reviewerID,
            reviewerRole: .bilingualTheology,
            qualificationDeclarationSHA256: String(repeating: "1", count: 64),
            independenceDeclarationSHA256: String(repeating: "2", count: 64),
            publicKeyBase64: publicKey.base64EncodedString()
        )
        let context = TranslationHumanReviewSignatureContext(
            schemaVersion: TranslationHumanReviewSettlement.currentSchemaVersion,
            policyRevision: TranslationHumanReviewEvidence.currentPolicyRevision,
            reportBinding: goldenBinding,
            reviewPacketSHA256: String(repeating: "f", count: 64),
            reviewerRegistrySHA256: String(repeating: "0", count: 64)
        )
        let payload = try TranslationHumanReviewEvidence.signingPayload(
            context: context,
            reviewer: reviewer,
            reviews: goldenReviews
        )
        let goldenSignature = try #require(Data(base64Encoded: expectedSignatureBase64))
        #expect(publicKey.hex == expectedPublicKeyHex)
        #expect(reviewerID == expectedReviewerID)
        #expect(TranslationQualificationSHA256.hash(data: payload) == expectedPayloadSHA256)
        #expect(privateKey.publicKey.isValidSignature(goldenSignature, for: payload))
    }

    private let privateKeyHex =
        "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"
    private let expectedPublicKeyHex =
        "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
    private let expectedReviewerID =
        "reviewer-21fe31dfa154a261626bf854046fd2271b7bed4b6abe45aa58877ef47f9721b9"
    private let expectedPayloadSHA256 =
        "8b820f89879cb886a72785502ca26c6030fa8cec6a7811d35c3d03ae19a10f18"
    private let expectedSignatureBase64 =
        "dkcjo+B3DmRXyLMtmCgx33247iPHV50+/6gOnPMi3ESAcrxZ3FhsgYHgHgngkyDej6A3M4KEcagXI5CTEK4wDw=="
    private var goldenBinding: TranslationHumanReviewReportBinding {
        TranslationHumanReviewReportBinding(
            reportSHA256: String(repeating: "a", count: 64),
            manifestSHA256: String(repeating: "b", count: 64),
            attemptIdentitySHA256: String(repeating: "c", count: 64)
        )
    }
    private var goldenReviews: [TranslationHumanReviewItem] {
        [
            TranslationHumanReviewItem(itemID: String(repeating: "d", count: 64), verdict: .pass),
            TranslationHumanReviewItem(itemID: String(repeating: "e", count: 64), verdict: .fail),
        ]
    }
}

extension Data {
    fileprivate init(hex: String) throws {
        guard hex.count.isMultiple(of: 2) else { throw GoldenFixtureError.invalidHex }
        var value = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<end], radix: 16) else {
                throw GoldenFixtureError.invalidHex
            }
            value.append(byte)
            index = end
        }
        self = value
    }

    fileprivate var hex: String { map { String(format: "%02x", $0) }.joined() }
}

private enum GoldenFixtureError: Error {
    case invalidHex
}
