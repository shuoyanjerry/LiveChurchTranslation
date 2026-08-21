import Foundation
import ModelRuntimeAPI
import SessionManagementAPI
import TranscriptAPI

struct LiveSessionStateMachine {
    private(set) var sessionID: UUID?
    private(set) var phase: LiveSessionPhase = .idle
    private(set) var transcript: [TranscriptEntry] = []
    private(set) var modelStatus: ModelRuntimeStatus?
    private(set) var statusMessage = "Ready"

    mutating func begin(sessionID: UUID) {
        self.sessionID = sessionID
        transcript = []
        transition(to: .requestingPermission, message: "Requesting microphone access…")
    }

    mutating func transition(to phase: LiveSessionPhase, message: String) {
        self.phase = phase
        statusMessage = message
    }

    mutating func setModelStatus(_ status: ModelRuntimeStatus) {
        modelStatus = status
    }

    mutating func receive(_ status: ModelRuntimeStatus) {
        setModelStatus(status)
        if phase == .preparingModel, let message = ModelStatusMessage.text(for: status) {
            transition(to: .preparingModel, message: message)
        }
    }

    mutating func append(_ entry: TranscriptEntry) {
        transcript.append(entry)
    }

    mutating func finish(message: String = "Transcript saved") {
        sessionID = nil
        transition(to: .idle, message: message)
    }

    mutating func fail(_ message: String) {
        sessionID = nil
        transition(to: .failed(message: message), message: message)
    }

    var snapshot: LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: sessionID,
            phase: phase,
            transcript: transcript,
            modelStatus: modelStatus,
            statusMessage: statusMessage
        )
    }
}
