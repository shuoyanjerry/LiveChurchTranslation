import Foundation

public enum TranslationHumanReviewEvidence {
    public static let currentPolicyRevision = "translation-human-review-v2"

    public static func encodeSettlement(
        _ settlement: TranslationHumanReviewSettlement
    ) throws -> Data {
        try canonicalData(settlement)
    }

    public static func decodeSettlement(
        from data: Data
    ) throws -> TranslationHumanReviewSettlement {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        do {
            let settlement = try JSONDecoder().decode(
                TranslationHumanReviewSettlement.self,
                from: data
            )
            try HumanReviewSettlementValidator.validate(settlement)
            return settlement
        } catch let error as TranslationQualificationError {
            throw error
        } catch {
            throw TranslationQualificationError.invalidJSON(
                "human review evidence does not match its strict schema"
            )
        }
    }

    public static func reviewerID(
        forPublicKeyBase64 value: String
    ) throws -> String {
        guard let data = Data(base64Encoded: value), data.count == 32,
            data.base64EncodedString() == value
        else {
            throw TranslationQualificationError.invalidReport(
                "human reviewer public key is not canonical"
            )
        }
        return "reviewer-" + TranslationQualificationSHA256.hash(data: data)
    }

    public static func reportBinding(
        for report: TranslationQualificationReport
    ) throws -> TranslationHumanReviewReportBinding {
        TranslationHumanReviewReportBinding(
            reportSHA256: TranslationQualificationSHA256.hash(
                data: try canonicalData(report)
            ),
            manifestSHA256: report.manifestSHA256,
            attemptIdentitySHA256: TranslationAttemptIdentityDigest.hash(report.attempts)
        )
    }

    public static func requiredReviewItemIDs(
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation
    ) throws -> [String] {
        guard TranslationProvenanceValidator.isReleaseBound(report, expectation: expectation) else {
            throw TranslationQualificationError.invalidReport(
                "human review coverage requires the trusted exact report"
            )
        }
        let binding = try reportBinding(for: report)
        return try TranslationHumanReviewRequirements.derive(
            attempts: expectation.trustedAttempts,
            segments: expectation.corpus.manifest.segments,
            reportBinding: binding
        ).map(\.itemID)
    }

    public static func signingPayload(
        context: TranslationHumanReviewSignatureContext,
        reviewer: TranslationHumanReviewerIdentity,
        reviews: [TranslationHumanReviewItem]
    ) throws -> Data {
        try canonicalData(
            SignedPayload(
                domain: "LIVE-CHURCH-TRANSLATION-HUMAN-REVIEW-V2",
                schemaVersion: context.schemaVersion,
                policyRevision: context.policyRevision,
                reportBinding: context.reportBinding,
                reviewPacketSHA256: context.reviewPacketSHA256,
                reviewerRegistrySHA256: context.reviewerRegistrySHA256,
                reviewer: reviewer,
                reviews: reviews
            )
        )
    }

    static func canonicalData<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(value)
        } catch {
            throw TranslationQualificationError.invalidReport(
                "human review evidence cannot be encoded deterministically"
            )
        }
    }

    private struct SignedPayload: Encodable {
        let domain: String
        let schemaVersion: Int
        let policyRevision: String
        let reportBinding: TranslationHumanReviewReportBinding
        let reviewPacketSHA256: String
        let reviewerRegistrySHA256: String
        let reviewer: TranslationHumanReviewerIdentity
        let reviews: [TranslationHumanReviewItem]
    }
}
