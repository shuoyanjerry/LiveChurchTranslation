import Foundation

public enum TranslationHumanReviewerRole: String, Codable, Hashable, Sendable {
    case bilingualTheology
    case independentLanguage
}

public struct TranslationHumanReviewReportBinding: Codable, Equatable, Sendable {
    public let reportSHA256: String
    public let manifestSHA256: String
    public let attemptIdentitySHA256: String

    public init(
        reportSHA256: String,
        manifestSHA256: String,
        attemptIdentitySHA256: String
    ) {
        self.reportSHA256 = reportSHA256
        self.manifestSHA256 = manifestSHA256
        self.attemptIdentitySHA256 = attemptIdentitySHA256
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            ["reportSHA256", "manifestSHA256", "attemptIdentitySHA256"]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        reportSHA256 = try values.decode(String.self, forKey: .reportSHA256)
        manifestSHA256 = try values.decode(String.self, forKey: .manifestSHA256)
        attemptIdentitySHA256 = try values.decode(String.self, forKey: .attemptIdentitySHA256)
    }
}

public struct TranslationHumanReviewerIdentity: Codable, Equatable, Sendable {
    public let reviewerID: String
    public let reviewerRole: TranslationHumanReviewerRole
    public let qualificationDeclarationSHA256: String
    public let independenceDeclarationSHA256: String
    public let publicKeyBase64: String

    public init(
        reviewerID: String,
        reviewerRole: TranslationHumanReviewerRole,
        qualificationDeclarationSHA256: String,
        independenceDeclarationSHA256: String,
        publicKeyBase64: String
    ) {
        self.reviewerID = reviewerID
        self.reviewerRole = reviewerRole
        self.qualificationDeclarationSHA256 = qualificationDeclarationSHA256
        self.independenceDeclarationSHA256 = independenceDeclarationSHA256
        self.publicKeyBase64 = publicKeyBase64
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            [
                "reviewerID", "reviewerRole", "qualificationDeclarationSHA256",
                "independenceDeclarationSHA256", "publicKeyBase64",
            ]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        reviewerID = try values.decode(String.self, forKey: .reviewerID)
        reviewerRole = try values.decode(TranslationHumanReviewerRole.self, forKey: .reviewerRole)
        qualificationDeclarationSHA256 = try values.decode(
            String.self,
            forKey: .qualificationDeclarationSHA256
        )
        independenceDeclarationSHA256 = try values.decode(
            String.self,
            forKey: .independenceDeclarationSHA256
        )
        publicKeyBase64 = try values.decode(String.self, forKey: .publicKeyBase64)
    }
}

public struct TranslationHumanReviewSubmission: Codable, Equatable, Sendable {
    public let reviewer: TranslationHumanReviewerIdentity
    public let reviews: [TranslationHumanReviewItem]
    public let signatureBase64: String

    public init(
        reviewer: TranslationHumanReviewerIdentity,
        reviews: [TranslationHumanReviewItem],
        signatureBase64: String
    ) {
        self.reviewer = reviewer
        self.reviews = reviews
        self.signatureBase64 = signatureBase64
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(decoder, ["reviewer", "reviews", "signatureBase64"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        reviewer = try values.decode(TranslationHumanReviewerIdentity.self, forKey: .reviewer)
        reviews = try values.decode([TranslationHumanReviewItem].self, forKey: .reviews)
        signatureBase64 = try values.decode(String.self, forKey: .signatureBase64)
    }
}

public struct TranslationHumanReviewSettlement: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let policyRevision: String
    public let reportBinding: TranslationHumanReviewReportBinding
    public let reviewPacketSHA256: String
    public let reviewerRegistrySHA256: String
    public let submissions: [TranslationHumanReviewSubmission]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        policyRevision: String,
        reportBinding: TranslationHumanReviewReportBinding,
        reviewPacketSHA256: String,
        reviewerRegistrySHA256: String,
        submissions: [TranslationHumanReviewSubmission]
    ) {
        self.schemaVersion = schemaVersion
        self.policyRevision = policyRevision
        self.reportBinding = reportBinding
        self.reviewPacketSHA256 = reviewPacketSHA256
        self.reviewerRegistrySHA256 = reviewerRegistrySHA256
        self.submissions = submissions
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            [
                "schemaVersion", "policyRevision", "reportBinding", "reviewPacketSHA256",
                "reviewerRegistrySHA256", "submissions",
            ]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        policyRevision = try values.decode(String.self, forKey: .policyRevision)
        reportBinding = try values.decode(
            TranslationHumanReviewReportBinding.self,
            forKey: .reportBinding
        )
        reviewPacketSHA256 = try values.decode(String.self, forKey: .reviewPacketSHA256)
        reviewerRegistrySHA256 = try values.decode(String.self, forKey: .reviewerRegistrySHA256)
        submissions = try values.decode([TranslationHumanReviewSubmission].self, forKey: .submissions)
    }
}
