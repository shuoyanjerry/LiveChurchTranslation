import Foundation

public enum GlossaryEnforcement: String, Codable, CaseIterable, Sendable {
    case required
    case preferred
}

public struct GlossaryEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var source: String
    public var target: String
    public var sourceAliases: [String]
    public var recognitionAliases: [String]
    public var targetVariants: [String]
    public var enforcement: GlossaryEnforcement
    public var note: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        source: String,
        target: String,
        sourceAliases: [String] = [],
        recognitionAliases: [String] = [],
        targetVariants: [String] = [],
        enforcement: GlossaryEnforcement = .preferred,
        note: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.sourceAliases = sourceAliases
        self.recognitionAliases = recognitionAliases
        self.targetVariants = targetVariants
        self.enforcement = enforcement
        self.note = note
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case target
        case sourceAliases
        case recognitionAliases
        case targetVariants
        case enforcement
        case note
        case isEnabled
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decode(String.self, forKey: .source)
        target = try container.decode(String.self, forKey: .target)
        sourceAliases = try container.decodeIfPresent([String].self, forKey: .sourceAliases) ?? []
        recognitionAliases =
            try container.decodeIfPresent(
                [String].self,
                forKey: .recognitionAliases
            ) ?? []
        targetVariants = try container.decodeIfPresent([String].self, forKey: .targetVariants) ?? []
        enforcement =
            try container.decodeIfPresent(GlossaryEnforcement.self, forKey: .enforcement)
            ?? .preferred
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
}

public struct GlossarySnapshot: Equatable, Sendable {
    public let revision: Int
    public let entries: [GlossaryEntry]

    public init(revision: Int, entries: [GlossaryEntry]) {
        self.revision = revision
        self.entries = entries
    }
}

public enum GlossaryError: LocalizedError, Sendable {
    case emptySource
    case emptyTarget
    case emptySourceAlias(String)
    case emptyRecognitionAlias(String)
    case emptyTargetVariant(String)
    case duplicateSource(String)
    case duplicateSourceAlias(String)
    case duplicateRecognitionAlias(String)
    case conflictingAlias(String)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptySource: "A glossary source term cannot be empty."
        case .emptyTarget: "A glossary translation cannot be empty."
        case .emptySourceAlias(let term):
            "A source alias for \(term) cannot be empty."
        case .emptyRecognitionAlias(let term):
            "A recognition alias for \(term) cannot be empty."
        case .emptyTargetVariant(let term):
            "A target variant for \(term) cannot be empty."
        case .duplicateSource(let term): "The glossary already contains \(term)."
        case .duplicateSourceAlias(let alias):
            "The source alias \(alias) appears more than once."
        case .duplicateRecognitionAlias(let alias):
            "The recognition alias \(alias) appears more than once."
        case .conflictingAlias(let alias):
            "The recognition alias \(alias) conflicts with a source term or alias."
        case .persistenceFailed(let message): "Could not save the glossary: \(message)"
        }
    }
}
