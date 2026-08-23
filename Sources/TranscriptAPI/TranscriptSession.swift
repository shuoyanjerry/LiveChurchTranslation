import Foundation

public enum TranscriptSessionKind: String, Codable, Sendable {
    case live
    case importedAudio
}

public struct TranscriptSession: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let entries: [TranscriptEntry]
    public let title: String?
    public let kind: TranscriptSessionKind
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        entries: [TranscriptEntry],
        title: String? = nil,
        kind: TranscriptSessionKind = .live,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
        self.title = title
        self.kind = kind
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, entries, title, kind, sourceLanguage, targetLanguage
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
        entries = try values.decode([TranscriptEntry].self, forKey: .entries)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        kind = try values.decodeIfPresent(TranscriptSessionKind.self, forKey: .kind) ?? .live
        sourceLanguage =
            try values.decodeIfPresent(String.self, forKey: .sourceLanguage)
            ?? "zh-Hans"
        targetLanguage = try values.decodeIfPresent(String.self, forKey: .targetLanguage) ?? "en"
    }
}
