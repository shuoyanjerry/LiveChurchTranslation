import Foundation
import TranscriptAPI

struct SessionManifest: Codable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let entryCount: Int
    let title: String?
    let kind: TranscriptSessionKind
    let sourceLanguage: String
    let targetLanguage: String

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, entryCount, title, kind, sourceLanguage, targetLanguage
    }

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        entryCount: Int,
        title: String?,
        kind: TranscriptSessionKind,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entryCount = entryCount
        self.title = title
        self.kind = kind
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
        entryCount = try values.decode(Int.self, forKey: .entryCount)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        kind = try values.decodeIfPresent(TranscriptSessionKind.self, forKey: .kind) ?? .live
        sourceLanguage =
            try values.decodeIfPresent(String.self, forKey: .sourceLanguage)
            ?? "zh-Hans"
        targetLanguage = try values.decodeIfPresent(String.self, forKey: .targetLanguage) ?? "en"
    }
}
