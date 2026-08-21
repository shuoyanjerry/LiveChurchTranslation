import ASRAPI
import Foundation
import TranslationAPI

public struct TranscriptEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let sourceText: String
    public let targetText: String
    public let startedMilliseconds: Int64
    public let endedMilliseconds: Int64
    public let translationMilliseconds: Int64
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        sequence: Int,
        sourceText: String,
        targetText: String,
        startedMilliseconds: Int64,
        endedMilliseconds: Int64,
        translationMilliseconds: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sequence = sequence
        self.sourceText = sourceText
        self.targetText = targetText
        self.startedMilliseconds = startedMilliseconds
        self.endedMilliseconds = endedMilliseconds
        self.translationMilliseconds = translationMilliseconds
        self.createdAt = createdAt
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
