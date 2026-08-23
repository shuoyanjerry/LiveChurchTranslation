import ScriptureAPI

public struct ScriptureQualificationManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let corpusID: String
    public let createdAt: String
    public let visibility: ScriptureQualificationVisibility
    public let mustNotCommit: Bool
    public let editionPair: ScriptureEditionPair
    public let grants: [ScriptureQualificationGrant]
    public let items: [ScriptureQualificationItem]
    public let translationPairs: [ScriptureQualificationTranslationPair]

    public init(
        schemaVersion: Int,
        corpusID: String,
        createdAt: String,
        visibility: ScriptureQualificationVisibility,
        mustNotCommit: Bool,
        editionPair: ScriptureEditionPair,
        grants: [ScriptureQualificationGrant],
        items: [ScriptureQualificationItem],
        translationPairs: [ScriptureQualificationTranslationPair]
    ) {
        self.schemaVersion = schemaVersion
        self.corpusID = corpusID
        self.createdAt = createdAt
        self.visibility = visibility
        self.mustNotCommit = mustNotCommit
        self.editionPair = editionPair
        self.grants = grants
        self.items = items
        self.translationPairs = translationPairs
    }
}

public enum ScriptureQualificationVisibility: String, Codable, Sendable {
    case gitignoredPrivateLocalQAOnly = "gitignored-private-local-qa-only"
}
