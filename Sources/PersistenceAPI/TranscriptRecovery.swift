import Foundation

public enum StoredTranscriptIntegrity: String, Codable, Equatable, Sendable {
    case active
    case complete
    case incomplete
    case recoveredAfterInterruption
}

public struct StoredTranscriptRejection: Codable, Hashable, Sendable {
    public let sentenceID: UUID
    public let sentenceOrdinal: Int
    public let stage: String
    public let failureCode: String

    public init(
        sentenceID: UUID,
        sentenceOrdinal: Int,
        stage: String,
        failureCode: String
    ) {
        self.sentenceID = sentenceID
        self.sentenceOrdinal = sentenceOrdinal
        self.stage = stage
        self.failureCode = failureCode
    }
}

public struct TranscriptFinalization: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case normal
        case recoveredAfterInterruption
    }

    public let kind: Kind
    public let pendingRecordCount: Int
    public let rejections: [StoredTranscriptRejection]
    public let quarantinedArtifactCount: Int
    public let hasUnrecoverableFailure: Bool

    public init(
        kind: Kind = .normal,
        pendingRecordCount: Int = 0,
        rejections: [StoredTranscriptRejection] = [],
        quarantinedArtifactCount: Int = 0,
        hasUnrecoverableFailure: Bool = false
    ) {
        self.kind = kind
        self.pendingRecordCount = max(0, pendingRecordCount)
        self.rejections = rejections
        self.quarantinedArtifactCount = max(0, quarantinedArtifactCount)
        self.hasUnrecoverableFailure = hasUnrecoverableFailure
    }

    public static let complete = TranscriptFinalization()

    public var integrity: StoredTranscriptIntegrity {
        let hasIncompleteWork =
            pendingRecordCount > 0
            || !rejections.isEmpty
            || quarantinedArtifactCount > 0
            || hasUnrecoverableFailure
        if hasIncompleteWork {
            return .incomplete
        }
        return kind == .recoveredAfterInterruption ? .recoveredAfterInterruption : .complete
    }
}

public struct TranscriptRecoveryCandidate: Equatable, Sendable {
    public let sessionID: UUID
    public let requiresTranscriptRecovery: Bool
    public let hasRecordingActivityArtifact: Bool

    public init(
        sessionID: UUID,
        requiresTranscriptRecovery: Bool,
        hasRecordingActivityArtifact: Bool
    ) {
        self.sessionID = sessionID
        self.requiresTranscriptRecovery = requiresTranscriptRecovery
        self.hasRecordingActivityArtifact = hasRecordingActivityArtifact
    }
}

public struct TranscriptRecoveryScanIssue: Equatable, Sendable {
    public enum Code: String, Equatable, Sendable {
        case unsafeRoot
        case rootInspectionFailed
        case enumerationFailed
        case unsafeSessionDirectory
        case manifestIdentifierMismatch
        case manifestInspectionFailed
    }

    public let code: Code
    public let sessionID: UUID?
    public let message: String
    public let technicalDetail: String?

    public init(
        code: Code,
        sessionID: UUID?,
        message: String,
        technicalDetail: String? = nil
    ) {
        self.code = code
        self.sessionID = sessionID
        self.message = message
        self.technicalDetail = technicalDetail
    }
}

public struct TranscriptRecoveryScan: Equatable, Sendable {
    public let candidates: [TranscriptRecoveryCandidate]
    public let issues: [TranscriptRecoveryScanIssue]
    public let didReachLimit: Bool

    public init(
        candidates: [TranscriptRecoveryCandidate],
        issues: [TranscriptRecoveryScanIssue],
        didReachLimit: Bool
    ) {
        self.candidates = candidates
        self.issues = issues
        self.didReachLimit = didReachLimit
    }
}

public struct RecoveredTranscriptSession: Equatable, Sendable {
    public let sessionID: UUID
    public let endedAt: Date
    public let entryCount: Int

    public init(sessionID: UUID, endedAt: Date, entryCount: Int) {
        self.sessionID = sessionID
        self.endedAt = endedAt
        self.entryCount = entryCount
    }
}

public enum InterruptedTranscriptRecoveryResult: Equatable, Sendable {
    case recovered(RecoveredTranscriptSession)
    case skippedActive
    case notRequired
}

public protocol InterruptedTranscriptRecoveryStore: Sendable {
    func interruptedSessions(maximumCount: Int) async -> TranscriptRecoveryScan

    func recoverInterruptedSession(
        sessionID: UUID,
        finalization: TranscriptFinalization
    ) async throws -> InterruptedTranscriptRecoveryResult
}

extension InterruptedTranscriptRecoveryStore {
    public func recoverInterruptedSession(
        sessionID: UUID
    ) async throws -> InterruptedTranscriptRecoveryResult {
        try await recoverInterruptedSession(
            sessionID: sessionID,
            finalization: TranscriptFinalization(kind: .recoveredAfterInterruption)
        )
    }
}
