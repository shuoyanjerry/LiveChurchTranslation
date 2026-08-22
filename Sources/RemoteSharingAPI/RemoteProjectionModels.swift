import Foundation

public enum RemoteSessionPhase: String, Codable, Sendable {
    case idle
    case preparing
    case listening
    case recognizing
    case translating
    case stopping
    case failed
}

public struct RemoteTranscriptEntry: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let revision: UInt64
    public let sourceText: String
    public let targetText: String
    public let createdAt: Date

    public init(
        id: UUID,
        sequence: Int,
        revision: UInt64,
        sourceText: String,
        targetText: String,
        createdAt: Date
    ) {
        self.id = id
        self.sequence = sequence
        self.revision = revision
        self.sourceText = sourceText
        self.targetText = targetText
        self.createdAt = createdAt
    }
}

public struct RemoteProjectionSnapshot: Equatable, Codable, Sendable {
    public let sessionID: UUID?
    public let revision: UInt64
    public let phase: RemoteSessionPhase
    public let statusMessage: String
    public let entries: [RemoteTranscriptEntry]

    public init(
        sessionID: UUID?,
        revision: UInt64,
        phase: RemoteSessionPhase,
        statusMessage: String,
        entries: [RemoteTranscriptEntry]
    ) {
        self.sessionID = sessionID
        self.revision = revision
        self.phase = phase
        self.statusMessage = statusMessage
        self.entries = entries
    }
}
