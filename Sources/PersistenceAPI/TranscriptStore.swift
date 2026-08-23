import Foundation
import TranscriptAPI

public struct StoredSessionSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let entryCount: Int
    public let location: URL
    public let title: String?
    public let kind: TranscriptSessionKind
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        entryCount: Int,
        location: URL,
        title: String? = nil,
        kind: TranscriptSessionKind = .live,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entryCount = entryCount
        self.location = location
        self.title = title
        self.kind = kind
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public protocol TranscriptStore: Sendable {
    func begin(_ session: TranscriptSession) async throws
    func append(_ entry: TranscriptEntry, to sessionID: UUID) async throws
    func load(sessionID: UUID) async throws -> TranscriptSession?
    func finish(_ session: TranscriptSession) async throws
    func recentSessions(limit: Int) async throws -> [StoredSessionSummary]
    func isSessionActive(sessionID: UUID) async -> Bool
    func delete(sessionID: UUID) async throws
}

public enum TranscriptStoreError: LocalizedError, Sendable {
    case sessionNotFound
    case sessionActive
    case invalidSessionDirectory
    case fileSystem(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound: "The transcript session could not be found."
        case .sessionActive:
            "The active meeting or its recoverable recording cannot be deleted. Stop it first."
        case .invalidSessionDirectory: "The session directory is not safe to remove."
        case .fileSystem(let message): "Transcript storage failed: \(message)"
        }
    }
}
