import Foundation

public struct RemoteProjectionEntryInput: Equatable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let sourceText: String
    public let targetText: String
    public let createdAt: Date

    public init(
        id: UUID,
        sequence: Int,
        sourceText: String,
        targetText: String,
        createdAt: Date
    ) {
        self.id = id
        self.sequence = sequence
        self.sourceText = sourceText
        self.targetText = targetText
        self.createdAt = createdAt
    }
}

public protocol RemoteProjectionUpdating: Sendable {
    func beginSession(id: UUID, message: String) async
    func updateState(phase: RemoteSessionPhase, message: String) async
    @discardableResult
    func upsert(_ input: RemoteProjectionEntryInput) async throws -> RemoteTranscriptEntry
    func heartbeat() async
}
