import Foundation
import ModelRuntimeAPI
import SessionManagementAPI
import TranscriptAPI

struct LiveSessionStateMachine {
    private(set) var sessionID: UUID?
    private(set) var phase: LiveSessionPhase = .idle
    private(set) var transcript: [TranscriptEntry] = []
    private(set) var captureStartedAt: Date?
    private(set) var sourceLanguage: String?
    private(set) var targetLanguage: String?
    private(set) var modelStatus: ModelRuntimeStatus?
    private(set) var statusMessage = "就绪"
    private var issueBuffer = BoundedLiveSessionIssueBuffer()
    private(set) var finalizationOutcome: LiveSessionFinalizationOutcome?

    mutating func begin(sessionID: UUID) {
        self.sessionID = sessionID
        transcript = []
        captureStartedAt = nil
        sourceLanguage = nil
        targetLanguage = nil
        issueBuffer = BoundedLiveSessionIssueBuffer()
        finalizationOutcome = nil
        transition(to: .requestingPermission, message: "正在请求麦克风权限…")
    }

    mutating func transition(to phase: LiveSessionPhase, message: String) {
        self.phase = phase
        statusMessage = message
    }

    mutating func setModelStatus(_ status: ModelRuntimeStatus) {
        modelStatus = status
    }

    mutating func setLanguages(source: String, target: String) {
        sourceLanguage = source
        targetLanguage = target
    }

    mutating func markCaptureStarted(at date: Date) {
        captureStartedAt = date
    }

    mutating func receive(_ status: ModelRuntimeStatus) {
        setModelStatus(status)
        if phase == .preparingModel, let message = ModelStatusMessage.text(for: status) {
            let prefix = captureStartedAt == nil ? "" : "录音中 · "
            transition(to: .preparingModel, message: prefix + message)
        }
    }

    mutating func append(_ entry: TranscriptEntry) {
        transcript.append(entry)
    }

    mutating func record(_ issue: LiveSessionIssue) {
        issueBuffer.append(issue)
    }

    mutating func finish(
        outcome: LiveSessionFinalizationOutcome,
        message: String
    ) {
        sessionID = nil
        captureStartedAt = nil
        finalizationOutcome = outcome
        transition(to: .idle, message: message)
    }

    mutating func fail(
        _ message: String,
        outcome: LiveSessionFinalizationOutcome? = nil
    ) {
        sessionID = nil
        captureStartedAt = nil
        finalizationOutcome = outcome
        transition(to: .failed(message: message), message: message)
    }

    var snapshot: LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: sessionID,
            phase: phase,
            transcript: transcript,
            captureStartedAt: captureStartedAt,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            modelStatus: modelStatus,
            statusMessage: statusMessage,
            issues: issueBuffer.values,
            finalizationOutcome: finalizationOutcome
        )
    }
}
