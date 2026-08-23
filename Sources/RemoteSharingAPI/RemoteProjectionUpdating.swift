import Foundation

public struct RemoteProjectionEntryInput: Equatable, Sendable {
    public let id: UUID
    public let sequence: Int
    public let sourceText: String
    public let targetText: String
    public let createdAt: Date
    public let sourceLanguage: String?
    public let targetLanguage: String?

    public init(
        id: UUID,
        sequence: Int,
        sourceText: String,
        targetText: String,
        createdAt: Date,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil
    ) {
        self.id = id
        self.sequence = sequence
        self.sourceText = sourceText
        self.targetText = targetText
        self.createdAt = createdAt
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public protocol RemoteProjectionUpdating: Sendable {
    func beginSession(id: UUID, message: String) async
    func updateState(phase: RemoteSessionPhase, message: String) async
    @discardableResult
    func upsert(_ input: RemoteProjectionEntryInput) async throws -> RemoteTranscriptEntry
    func heartbeat() async
}
