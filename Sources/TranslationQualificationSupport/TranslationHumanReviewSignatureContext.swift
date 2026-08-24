public struct TranslationHumanReviewSignatureContext: Equatable, Sendable {
    public let schemaVersion: Int
    public let policyRevision: String
    public let reportBinding: TranslationHumanReviewReportBinding
    public let reviewPacketSHA256: String
    public let reviewerRegistrySHA256: String

    public init(
        schemaVersion: Int,
        policyRevision: String,
        reportBinding: TranslationHumanReviewReportBinding,
        reviewPacketSHA256: String,
        reviewerRegistrySHA256: String
    ) {
        self.schemaVersion = schemaVersion
        self.policyRevision = policyRevision
        self.reportBinding = reportBinding
        self.reviewPacketSHA256 = reviewPacketSHA256
        self.reviewerRegistrySHA256 = reviewerRegistrySHA256
    }
}

extension TranslationHumanReviewSettlement {
    public var signatureContext: TranslationHumanReviewSignatureContext {
        TranslationHumanReviewSignatureContext(
            schemaVersion: schemaVersion,
            policyRevision: policyRevision,
            reportBinding: reportBinding,
            reviewPacketSHA256: reviewPacketSHA256,
            reviewerRegistrySHA256: reviewerRegistrySHA256
        )
    }
}
