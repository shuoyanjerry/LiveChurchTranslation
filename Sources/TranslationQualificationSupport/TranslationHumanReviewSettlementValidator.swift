import Foundation

enum HumanReviewSettlementValidator {
    static func validate(_ settlement: TranslationHumanReviewSettlement) throws {
        guard
            settlement.schemaVersion == TranslationHumanReviewSettlement.currentSchemaVersion,
            settlement.policyRevision == TranslationHumanReviewEvidence.currentPolicyRevision,
            validBinding(settlement.reportBinding),
            TranslationProvenanceValidator.isSHA(settlement.reviewPacketSHA256),
            TranslationProvenanceValidator.isSHA(settlement.reviewerRegistrySHA256),
            settlement.submissions.count == 2,
            settlement.submissions.allSatisfy(validSubmission)
        else {
            throw TranslationQualificationError.invalidReport(
                "human review evidence is invalid"
            )
        }
    }

    private static func validBinding(
        _ binding: TranslationHumanReviewReportBinding
    ) -> Bool {
        TranslationProvenanceValidator.isSHA(binding.reportSHA256)
            && TranslationProvenanceValidator.isSHA(binding.manifestSHA256)
            && TranslationProvenanceValidator.isSHA(binding.attemptIdentitySHA256)
    }

    private static func validSubmission(
        _ submission: TranslationHumanReviewSubmission
    ) -> Bool {
        let itemIDs = submission.reviews.map(\.itemID)
        return HumanReviewSignatureValidator.validIdentity(submission.reviewer)
            && canonicalBase64(submission.signatureBase64, byteCount: 64)
            && itemIDs == itemIDs.sorted()
            && Set(itemIDs).count == itemIDs.count
            && itemIDs.allSatisfy(HumanReviewSignatureValidator.validItemID)
    }

    private static func canonicalBase64(
        _ value: String,
        byteCount: Int
    ) -> Bool {
        guard let data = Data(base64Encoded: value) else { return false }
        return data.count == byteCount && data.base64EncodedString() == value
    }
}
