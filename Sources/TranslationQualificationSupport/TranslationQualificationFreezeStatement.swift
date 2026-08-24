import Foundation

public struct TranslationQualificationFreezeStatement: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let currentPolicyRevision = "hymt-qualification-freeze-v1"

    public let schemaVersion: Int
    public let policyRevision: String
    public let requestID: String
    public let reportFilename: String
    public let postflightFilename: String
    public let reviewPacketFilename: String
    public let reportFileSHA256: String
    public let postflightFileSHA256: String
    public let reviewPacketSHA256: String
    public let attemptContentsSHA256: String
    public let reportBinding: TranslationHumanReviewReportBinding
    public let executionProvenance: TranslationExecutionProvenance
    public let provider: TranslationQualificationProvider
    public let environment: TranslationQualificationEnvironment
    public let frozenAt: String

    public init(
        requestID: String,
        reportFilename: String,
        postflightFilename: String,
        reviewPacketFilename: String,
        reportFileSHA256: String,
        postflightFileSHA256: String,
        reviewPacketSHA256: String,
        attemptContentsSHA256: String,
        reportBinding: TranslationHumanReviewReportBinding,
        executionProvenance: TranslationExecutionProvenance,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        frozenAt: String
    ) {
        schemaVersion = Self.currentSchemaVersion
        policyRevision = Self.currentPolicyRevision
        self.requestID = requestID
        self.reportFilename = reportFilename
        self.postflightFilename = postflightFilename
        self.reviewPacketFilename = reviewPacketFilename
        self.reportFileSHA256 = reportFileSHA256
        self.postflightFileSHA256 = postflightFileSHA256
        self.reviewPacketSHA256 = reviewPacketSHA256
        self.attemptContentsSHA256 = attemptContentsSHA256
        self.reportBinding = reportBinding
        self.executionProvenance = executionProvenance
        self.provider = provider
        self.environment = environment
        self.frozenAt = frozenAt
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            [
                "schemaVersion", "policyRevision", "requestID", "reportFilename",
                "postflightFilename", "reviewPacketFilename", "reportFileSHA256",
                "postflightFileSHA256", "reviewPacketSHA256", "attemptContentsSHA256",
                "reportBinding", "executionProvenance", "provider", "environment", "frozenAt",
            ]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        policyRevision = try values.decode(String.self, forKey: .policyRevision)
        requestID = try values.decode(String.self, forKey: .requestID)
        reportFilename = try values.decode(String.self, forKey: .reportFilename)
        postflightFilename = try values.decode(String.self, forKey: .postflightFilename)
        reviewPacketFilename = try values.decode(String.self, forKey: .reviewPacketFilename)
        reportFileSHA256 = try values.decode(String.self, forKey: .reportFileSHA256)
        postflightFileSHA256 = try values.decode(String.self, forKey: .postflightFileSHA256)
        reviewPacketSHA256 = try values.decode(String.self, forKey: .reviewPacketSHA256)
        attemptContentsSHA256 = try values.decode(String.self, forKey: .attemptContentsSHA256)
        reportBinding = try values.decode(
            TranslationHumanReviewReportBinding.self,
            forKey: .reportBinding
        )
        executionProvenance = try values.decode(
            TranslationExecutionProvenance.self,
            forKey: .executionProvenance
        )
        provider = try values.decode(TranslationQualificationProvider.self, forKey: .provider)
        environment = try values.decode(
            TranslationQualificationEnvironment.self,
            forKey: .environment
        )
        frozenAt = try values.decode(String.self, forKey: .frozenAt)
    }
}

public struct TranslationQualificationSignedFreeze: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let statement: TranslationQualificationFreezeStatement
    public let authorityKeyID: String
    public let signatureBase64: String

    public init(
        statement: TranslationQualificationFreezeStatement,
        authorityKeyID: String,
        signatureBase64: String
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.statement = statement
        self.authorityKeyID = authorityKeyID
        self.signatureBase64 = signatureBase64
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(
            decoder,
            ["schemaVersion", "statement", "authorityKeyID", "signatureBase64"]
        )
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        statement = try values.decode(
            TranslationQualificationFreezeStatement.self,
            forKey: .statement
        )
        authorityKeyID = try values.decode(String.self, forKey: .authorityKeyID)
        signatureBase64 = try values.decode(String.self, forKey: .signatureBase64)
    }
}

public struct TranslationFreezeTrustPolicy: Sendable {
    public let policyRevision: String
    public let authorityPublicKeysByID: [String: String]

    public init(policyRevision: String, authorityPublicKeysByID: [String: String]) {
        self.policyRevision = policyRevision
        self.authorityPublicKeysByID = authorityPublicKeysByID
    }
}
