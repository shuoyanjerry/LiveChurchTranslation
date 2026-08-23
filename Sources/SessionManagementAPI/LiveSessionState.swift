import Foundation
import ModelRuntimeAPI
import TranscriptAPI

public enum LiveSessionPhase: Equatable, Sendable {
    case idle
    case requestingPermission
    case preparingModel
    case listening
    case recognizing
    case translating
    case stopping
    case failed(message: String)
}

/// Stable processing boundaries used to classify a session issue.
public enum LiveSessionIssueStage: Equatable, Sendable {
    case preparation
    case audioProcessing
    case recognition
    case translation
    case persistence
    case finalization
}

/// Immutable diagnostic state for work that could not complete.
public struct LiveSessionIssue: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stage: LiveSessionIssueStage
    public let utteranceSequence: UInt64?
    public let message: String
    public let isRecoverable: Bool

    public init(
        id: UUID = UUID(),
        stage: LiveSessionIssueStage,
        utteranceSequence: UInt64? = nil,
        message: String,
        isRecoverable: Bool
    ) {
        self.id = id
        self.stage = stage
        self.utteranceSequence = utteranceSequence
        self.message = message
        self.isRecoverable = isRecoverable
    }
}

/// Durable outcome produced after capture and inference have drained.
public enum LiveSessionFinalizationOutcome: Equatable, Sendable {
    case saved
    case savedWithUnresolvedUtterances(count: Int)
    case savedWithIncompleteTranscript(
        rejectedUtteranceCount: Int,
        recoverableUtteranceCount: Int
    )
    case cancelledBeforeCapture
    case failedBeforeCapture
    case saveFailed(message: String, unresolvedUtteranceCount: Int)
}

public struct LiveSessionSnapshot: Equatable, Sendable {
    public let sessionID: UUID?
    public let phase: LiveSessionPhase
    public let transcript: [TranscriptEntry]
    /// Set only after the capture provider has started the local audio stream.
    public let captureStartedAt: Date?
    public let sourceLanguage: String?
    public let targetLanguage: String?
    public let modelStatus: ModelRuntimeStatus?
    public let statusMessage: String
    /// Issues remain visible after the session reaches a terminal phase.
    public let issues: [LiveSessionIssue]
    /// Set only after the session pipeline has been drained and finalized.
    public let finalizationOutcome: LiveSessionFinalizationOutcome?

    public init(
        sessionID: UUID?,
        phase: LiveSessionPhase,
        transcript: [TranscriptEntry],
        captureStartedAt: Date? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        modelStatus: ModelRuntimeStatus?,
        statusMessage: String,
        issues: [LiveSessionIssue] = [],
        finalizationOutcome: LiveSessionFinalizationOutcome? = nil
    ) {
        self.sessionID = sessionID
        self.phase = phase
        self.transcript = transcript
        self.captureStartedAt = captureStartedAt
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.modelStatus = modelStatus
        self.statusMessage = statusMessage
        self.issues = issues
        self.finalizationOutcome = finalizationOutcome
    }
}

public enum LiveSessionEvent: Equatable, Sendable {
    case stateChanged(LiveSessionSnapshot)
    case transcriptAppended(TranscriptEntry)
    case recoverableError(String)
}
