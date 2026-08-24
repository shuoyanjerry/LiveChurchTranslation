import Foundation

public struct TranslationHumanReviewerRegistry: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let policyRevision: String
    public let registryID: String
    public let registryRevision: Int
    public let rootKeyID: String
    public let reviewers: [TranslationHumanReviewerIdentity]
    public let signatureBase64: String

    public init(
        schemaVersion: Int = currentSchemaVersion,
        policyRevision: String,
        registryID: String,
        registryRevision: Int,
        rootKeyID: String,
        reviewers: [TranslationHumanReviewerIdentity],
        signatureBase64: String
    ) {
        self.schemaVersion = schemaVersion
        self.policyRevision = policyRevision
        self.registryID = registryID
        self.registryRevision = registryRevision
        self.rootKeyID = rootKeyID
        self.reviewers = reviewers
        self.signatureBase64 = signatureBase64
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            [
                "schemaVersion", "policyRevision", "registryID", "registryRevision",
                "rootKeyID", "reviewers", "signatureBase64",
            ]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        policyRevision = try values.decode(String.self, forKey: .policyRevision)
        registryID = try values.decode(String.self, forKey: .registryID)
        registryRevision = try values.decode(Int.self, forKey: .registryRevision)
        rootKeyID = try values.decode(String.self, forKey: .rootKeyID)
        reviewers = try values.decode(
            [TranslationHumanReviewerIdentity].self,
            forKey: .reviewers
        )
        signatureBase64 = try values.decode(String.self, forKey: .signatureBase64)
    }
}
