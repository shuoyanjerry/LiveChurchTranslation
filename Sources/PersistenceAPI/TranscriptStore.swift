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
    public let integrity: StoredTranscriptIntegrity
    public let pendingRecordCount: Int
    public let rejectedSentenceCount: Int
    public let quarantinedArtifactCount: Int

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        entryCount: Int,
        location: URL,
        title: String? = nil,
        kind: TranscriptSessionKind = .live,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en",
        integrity: StoredTranscriptIntegrity? = nil,
        pendingRecordCount: Int = 0,
        rejectedSentenceCount: Int = 0,
        quarantinedArtifactCount: Int = 0
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
        self.integrity = integrity ?? (endedAt == nil ? .active : .complete)
        self.pendingRecordCount = pendingRecordCount
        self.rejectedSentenceCount = rejectedSentenceCount
        self.quarantinedArtifactCount = quarantinedArtifactCount
    }
}

public protocol TranscriptStore: Sendable {
    func begin(_ session: TranscriptSession) async throws
    func append(_ entry: TranscriptEntry, to sessionID: UUID) async throws
    func load(sessionID: UUID) async throws -> TranscriptSession?
    func finish(
        _ session: TranscriptSession,
        finalization: TranscriptFinalization
    ) async throws
    func recentSessions(limit: Int) async throws -> [StoredSessionSummary]
    func isSessionActive(sessionID: UUID) async -> Bool
    func delete(sessionID: UUID) async throws
}

extension TranscriptStore {
    public func finish(_ session: TranscriptSession) async throws {
        try await finish(session, finalization: .complete)
    }
}

public enum TranscriptStoreError: LocalizedError, Sendable {
    case sessionNotFound
    case sessionActive
    case invalidSessionDirectory
    case fileSystem(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound: "找不到这场会议的听抄稿。"
        case .sessionActive:
            "当前会议或仍可恢复的录音不能删除。请先停止会议。"
        case .invalidSessionDirectory: "会议目录不符合安全删除条件。"
        case .fileSystem(let message): "听抄稿存储失败：\(message)"
        }
    }
}
