import ScriptureAPI

public struct ScriptureQualificationSourceDeclaration: Codable, Sendable {
    public let id: String
    public let editionID: ScriptureEditionID
    public let sourceAttribution: String
    public let declaredBy: String
    public let declarationPath: String
    public let declarationSHA256: String
    public let declaredAt: String
    public let permittedUses: ScriptureQualificationPermittedUses

    public init(
        id: String,
        editionID: ScriptureEditionID,
        sourceAttribution: String,
        declaredBy: String,
        declarationPath: String,
        declarationSHA256: String,
        declaredAt: String,
        permittedUses: ScriptureQualificationPermittedUses
    ) {
        self.id = id
        self.editionID = editionID
        self.sourceAttribution = sourceAttribution
        self.declaredBy = declaredBy
        self.declarationPath = declarationPath
        self.declarationSHA256 = declarationSHA256
        self.declaredAt = declaredAt
        self.permittedUses = permittedUses
    }
}

public struct ScriptureQualificationPermittedUses: Codable, Sendable {
    public let textEvaluationAllowed: Bool
    public let audioEvaluationAllowed: Bool
    public let recordingEvaluationAllowed: Bool
    public let asrEvaluationAllowed: Bool
    public let crossLanguageEvaluationAllowed: Bool
    public let modelAdjustmentAllowed: Bool
    public let modelTrainingAllowed: Bool
    public let redistributionAllowed: Bool

    public init(
        textEvaluationAllowed: Bool,
        audioEvaluationAllowed: Bool,
        recordingEvaluationAllowed: Bool,
        asrEvaluationAllowed: Bool,
        crossLanguageEvaluationAllowed: Bool,
        modelAdjustmentAllowed: Bool,
        modelTrainingAllowed: Bool,
        redistributionAllowed: Bool
    ) {
        self.textEvaluationAllowed = textEvaluationAllowed
        self.audioEvaluationAllowed = audioEvaluationAllowed
        self.recordingEvaluationAllowed = recordingEvaluationAllowed
        self.asrEvaluationAllowed = asrEvaluationAllowed
        self.crossLanguageEvaluationAllowed = crossLanguageEvaluationAllowed
        self.modelAdjustmentAllowed = modelAdjustmentAllowed
        self.modelTrainingAllowed = modelTrainingAllowed
        self.redistributionAllowed = redistributionAllowed
    }
}
