import ASRAPI
import Foundation
import TranslationAPI

public struct TranscriptSourceCorrection: Codable, Equatable, Sendable {
    public let observedText: String
    public let replacementText: String

    public init(observedText: String, replacementText: String) {
        self.observedText = observedText
        self.replacementText = replacementText
    }
}

public struct TranscriptSourceAudit: Equatable, Sendable {
    public let rawText: String
    public let corrections: [TranscriptSourceCorrection]

    public init(rawText: String, corrections: [TranscriptSourceCorrection]) {
        self.rawText = rawText
        self.corrections = corrections
    }
}

public struct TranscriptEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let rawSourceText: String
    public let sourceText: String
    public let sourceCorrections: [TranscriptSourceCorrection]
    public let targetText: String
    public let startedMilliseconds: Int64
    public let endedMilliseconds: Int64
    public let translationMilliseconds: Int64
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sequence: Int,
        rawSourceText: String? = nil,
        sourceText: String,
        sourceCorrections: [TranscriptSourceCorrection] = [],
        targetText: String,
        startedMilliseconds: Int64,
        endedMilliseconds: Int64,
        translationMilliseconds: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sequence = sequence
        self.rawSourceText = rawSourceText ?? sourceText
        self.sourceText = sourceText
        self.sourceCorrections = sourceCorrections
        self.targetText = targetText
        self.startedMilliseconds = startedMilliseconds
        self.endedMilliseconds = endedMilliseconds
        self.translationMilliseconds = translationMilliseconds
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, sequence, rawSourceText, sourceText, sourceCorrections
        case targetText, startedMilliseconds, endedMilliseconds
        case translationMilliseconds, createdAt
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        sequence = try values.decode(Int.self, forKey: .sequence)
        sourceText = try values.decode(String.self, forKey: .sourceText)
        rawSourceText = try values.decodeIfPresent(String.self, forKey: .rawSourceText) ?? sourceText
        sourceCorrections =
            try values.decodeIfPresent(
                [TranscriptSourceCorrection].self,
                forKey: .sourceCorrections
            ) ?? []
        targetText = try values.decode(String.self, forKey: .targetText)
        startedMilliseconds = try values.decode(Int64.self, forKey: .startedMilliseconds)
        endedMilliseconds = try values.decode(Int64.self, forKey: .endedMilliseconds)
        translationMilliseconds = try values.decode(Int64.self, forKey: .translationMilliseconds)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
    }
}

public struct TranscriptSession: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let entries: [TranscriptEntry]

    public init(id: UUID, startedAt: Date, endedAt: Date?, entries: [TranscriptEntry]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
    }
}
