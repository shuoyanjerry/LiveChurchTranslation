import ScriptureAPI

public struct ScriptureQualificationGrant: Codable, Sendable {
    public let id: String
    public let editionID: ScriptureEditionID
    public let licensor: String
    public let licensee: String
    public let agreementID: String
    public let evidencePath: String
    public let evidenceSHA256: String
    public let validFrom: String
    public let expiresAt: String?
    public let territories: [String]
    public let reviewedBy: String
    public let reviewedAt: String
    public let rights: ScriptureQualificationRights

    public init(
        id: String,
        editionID: ScriptureEditionID,
        licensor: String,
        licensee: String,
        agreementID: String,
        evidencePath: String,
        evidenceSHA256: String,
        validFrom: String,
        expiresAt: String?,
        territories: [String],
        reviewedBy: String,
        reviewedAt: String,
        rights: ScriptureQualificationRights
    ) {
        self.id = id
        self.editionID = editionID
        self.licensor = licensor
        self.licensee = licensee
        self.agreementID = agreementID
        self.evidencePath = evidencePath
        self.evidenceSHA256 = evidenceSHA256
        self.validFrom = validFrom
        self.expiresAt = expiresAt
        self.territories = territories
        self.reviewedBy = reviewedBy
        self.reviewedAt = reviewedAt
        self.rights = rights
    }
}

public struct ScriptureQualificationRights: Codable, Sendable {
    public let textUseAuthorized: Bool
    public let audioUseAuthorized: Bool
    public let recordingUseAuthorized: Bool
    public let asrEvaluationAuthorized: Bool
    public let crossLanguageEvaluationAuthorized: Bool
    public let modelTrainingAuthorized: Bool
    public let redistributionAuthorized: Bool

    public init(
        textUseAuthorized: Bool,
        audioUseAuthorized: Bool,
        recordingUseAuthorized: Bool,
        asrEvaluationAuthorized: Bool,
        crossLanguageEvaluationAuthorized: Bool,
        modelTrainingAuthorized: Bool,
        redistributionAuthorized: Bool
    ) {
        self.textUseAuthorized = textUseAuthorized
        self.audioUseAuthorized = audioUseAuthorized
        self.recordingUseAuthorized = recordingUseAuthorized
        self.asrEvaluationAuthorized = asrEvaluationAuthorized
        self.crossLanguageEvaluationAuthorized = crossLanguageEvaluationAuthorized
        self.modelTrainingAuthorized = modelTrainingAuthorized
        self.redistributionAuthorized = redistributionAuthorized
    }
}
