import Foundation

public enum UtteranceRejectionStage: String, Codable, Hashable, Sendable {
    case recognition
    case translation
}

/// Stable, non-sensitive evidence that one translation unit reached a terminal rejection.
/// Sentence-named fields are retained for durable format compatibility.
public struct UtteranceRejectionReceipt: Codable, Hashable, Sendable {
    public let sentenceID: UUID
    public let sentenceOrdinal: Int
    public let stage: UtteranceRejectionStage
    public let failureCode: String

    public init(
        sentenceID: UUID,
        sentenceOrdinal: Int,
        stage: UtteranceRejectionStage,
        failureCode: String
    ) {
        self.sentenceID = sentenceID
        self.sentenceOrdinal = sentenceOrdinal
        self.stage = stage
        self.failureCode = failureCode
    }
}

public enum UtteranceRecoveryResolution: Equatable, Sendable {
    case completed
    case ignored
    case terminallyRejected([UtteranceRejectionReceipt])
}

public struct UtteranceRecoverySessionSummary: Equatable, Sendable {
    public let pendingRecordCount: Int
    public let rejections: [UtteranceRejectionReceipt]
    public let quarantinedArtifactCount: Int

    public init(
        pendingRecordCount: Int,
        rejections: [UtteranceRejectionReceipt],
        quarantinedArtifactCount: Int
    ) {
        self.pendingRecordCount = max(0, pendingRecordCount)
        self.rejections = rejections
        self.quarantinedArtifactCount = max(0, quarantinedArtifactCount)
    }

    public static let empty = UtteranceRecoverySessionSummary(
        pendingRecordCount: 0,
        rejections: [],
        quarantinedArtifactCount: 0
    )
}

/// Durable terminal record retained after rejected segment audio leaves the retry queue.
public struct TerminalUtteranceRejectionRecord: Codable, Equatable, Sendable {
    public let id: PendingUtteranceID
    public let resolvedAt: Date
    public let receipts: [UtteranceRejectionReceipt]

    public init(
        id: PendingUtteranceID,
        resolvedAt: Date,
        receipts: [UtteranceRejectionReceipt]
    ) {
        self.id = id
        self.resolvedAt = resolvedAt
        self.receipts = receipts
    }
}
