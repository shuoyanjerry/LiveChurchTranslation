import CryptoKit
import Foundation
import TranslationQualificationSupport

enum SyntheticHumanReviewSettlementFactory {
    static var trustedReviewers: [TranslationHumanReviewerIdentity] {
        [
            reviewer(nil, role: .bilingualTheology, key: trustedFirstKey),
            reviewer(nil, role: .independentLanguage, key: trustedSecondKey),
        ]
    }

    static func make(
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        policyRevision: String = TranslationHumanReviewEvidence.currentPolicyRevision,
        binding: TranslationHumanReviewReportBinding? = nil,
        firstReviewerID: String? = nil,
        secondReviewerID: String? = nil,
        firstRole: TranslationHumanReviewerRole = .bilingualTheology,
        secondRole: TranslationHumanReviewerRole = .independentLanguage,
        firstKey: Curve25519.Signing.PrivateKey? = nil,
        secondKey: Curve25519.Signing.PrivateKey? = nil,
        reviewPacketSHA256: String? = nil,
        reviewerRegistrySHA256: String? = nil,
        firstReviews: [TranslationHumanReviewItem]? = nil,
        secondReviews: [TranslationHumanReviewItem]? = nil
    ) throws -> TranslationHumanReviewSettlement {
        let firstKey = firstKey ?? trustedFirstKey
        let secondKey = secondKey ?? trustedSecondKey
        let resolvedBinding = try binding ?? TranslationHumanReviewEvidence.reportBinding(for: report)
        let defaults = try reviews(report: report, expectation: expectation)
        let firstReviewer = reviewer(firstReviewerID, role: firstRole, key: firstKey)
        let secondReviewer = reviewer(secondReviewerID, role: secondRole, key: secondKey)
        let packetSHA256 = reviewPacketSHA256 ?? trustedReviewPacketSHA256
        let registrySHA256 = reviewerRegistrySHA256 ?? trustedReviewerRegistrySHA256
        let context = signatureContext(
            policyRevision: policyRevision,
            binding: resolvedBinding,
            packetSHA256: packetSHA256,
            registrySHA256: registrySHA256
        )
        let submissions = try [
            submission(
                reviewer: firstReviewer,
                privateKey: firstKey,
                reviews: firstReviews ?? defaults,
                context: context
            ),
            submission(
                reviewer: secondReviewer,
                privateKey: secondKey,
                reviews: secondReviews ?? defaults,
                context: context
            ),
        ]
        return TranslationHumanReviewSettlement(
            policyRevision: policyRevision,
            reportBinding: resolvedBinding,
            reviewPacketSHA256: packetSHA256,
            reviewerRegistrySHA256: registrySHA256,
            submissions: submissions
        )
    }

    static func data(_ settlement: TranslationHumanReviewSettlement) throws -> Data {
        try TranslationHumanReviewEvidence.encodeSettlement(settlement)
    }

    static func reviews(
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        verdict: TranslationHumanReviewVerdict = .pass
    ) throws -> [TranslationHumanReviewItem] {
        try TranslationHumanReviewEvidence.requiredReviewItemIDs(
            report: report,
            expectation: expectation
        ).map { TranslationHumanReviewItem(itemID: $0, verdict: verdict) }
    }

    static func submission(
        reviewer: TranslationHumanReviewerIdentity,
        privateKey: Curve25519.Signing.PrivateKey,
        reviews: [TranslationHumanReviewItem],
        context: TranslationHumanReviewSignatureContext
    ) throws -> TranslationHumanReviewSubmission {
        let payload = try TranslationHumanReviewEvidence.signingPayload(
            context: context,
            reviewer: reviewer,
            reviews: reviews
        )
        let signature = try privateKey.signature(for: payload).base64EncodedString()
        return TranslationHumanReviewSubmission(
            reviewer: reviewer,
            reviews: reviews,
            signatureBase64: signature
        )
    }
}

extension SyntheticHumanReviewSettlementFactory {
    private static func signatureContext(
        policyRevision: String,
        binding: TranslationHumanReviewReportBinding,
        packetSHA256: String,
        registrySHA256: String
    ) -> TranslationHumanReviewSignatureContext {
        TranslationHumanReviewSignatureContext(
            schemaVersion: TranslationHumanReviewSettlement.currentSchemaVersion,
            policyRevision: policyRevision,
            reportBinding: binding,
            reviewPacketSHA256: packetSHA256,
            reviewerRegistrySHA256: registrySHA256
        )
    }

    private static func declarationHash(_ values: String...) -> String {
        TranslationQualificationSHA256.hash(data: Data(values.joined(separator: "\0").utf8))
    }

    private static func reviewer(
        _ reviewerID: String?,
        role: TranslationHumanReviewerRole,
        key: Curve25519.Signing.PrivateKey
    ) -> TranslationHumanReviewerIdentity {
        let reviewerID =
            reviewerID ?? "reviewer-"
            + TranslationQualificationSHA256.hash(
                data: key.publicKey.rawRepresentation
            )
        return TranslationHumanReviewerIdentity(
            reviewerID: reviewerID,
            reviewerRole: role,
            qualificationDeclarationSHA256: declarationHash(
                "qualification", reviewerID, role.rawValue
            ),
            independenceDeclarationSHA256: declarationHash(
                "independence", reviewerID, role.rawValue
            ),
            publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    private static let trustedFirstKey = Curve25519.Signing.PrivateKey()
    private static let trustedSecondKey = Curve25519.Signing.PrivateKey()

    static let trustedReviewPacketSHA256 = String(repeating: "6", count: 64)
    static let trustedReviewerRegistrySHA256 = String(repeating: "7", count: 64)
}

extension SyntheticHumanReviewSettlementFactory {
    static func expectation(
        report: TranslationQualificationReport,
        corpus: TranslationQualificationCorpus
    ) throws -> TranslationReleaseExpectation {
        guard let provenance = report.executionProvenance else {
            throw TranslationQualificationError.invalidReport("synthetic provenance missing")
        }
        return try TranslationReleaseExpectation(
            trustedExecutionProvenance: provenance,
            corpus: corpus,
            provider: report.provider,
            environment: report.environment,
            attempts: report.attempts,
            trustedHumanReviewers: trustedReviewers,
            trustedHumanReviewPacketSHA256: trustedReviewPacketSHA256,
            trustedHumanReviewerRegistrySHA256: trustedReviewerRegistrySHA256
        )
    }
}
