import Foundation
import TranscriptAPI

public struct StoredSessionSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let entryCount: Int
    public let location: URL

    public init(id: UUID, startedAt: Date, endedAt: Date?, entryCount: Int, location: URL) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entryCount = entryCount
        self.location = location
    }
}

public protocol TranscriptStore: Sendable {
    func begin(_ session: TranscriptSession) async throws
    func append(_ entry: TranscriptEntry, to sessionID: UUID) async throws
    func finish(_ session: TranscriptSession) async throws
    func recentSessions(limit: Int) async throws -> [StoredSessionSummary]
}

public enum TranscriptStoreError: LocalizedError, Sendable {
    case sessionNotFound
    case fileSystem(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound: "The transcript session could not be found."
        case .fileSystem(let message): "Transcript storage failed: \(message)"
        }
    }
}
