import Foundation

public struct GlossaryEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var source: String
    public var target: String
    public var recognitionAliases: [String]
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        source: String,
        target: String,
        recognitionAliases: [String] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.recognitionAliases = recognitionAliases
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case target
        case recognitionAliases
        case isEnabled
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decode(String.self, forKey: .source)
        target = try container.decode(String.self, forKey: .target)
        recognitionAliases =
            try container.decodeIfPresent(
                [String].self,
                forKey: .recognitionAliases
            ) ?? []
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
    case emptyRecognitionAlias(String)
    case duplicateSource(String)
    case duplicateRecognitionAlias(String)
    case persistenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptySource: "A glossary source term cannot be empty."
        case .emptyTarget: "A glossary translation cannot be empty."
        case .emptyRecognitionAlias(let term):
            "A recognition alias for \(term) cannot be empty."
        case .duplicateSource(let term): "The glossary already contains \(term)."
        case .duplicateRecognitionAlias(let alias):
            "The recognition alias \(alias) appears more than once."
        case .persistenceFailed(let message): "Could not save the glossary: \(message)"
        }
    }
}
