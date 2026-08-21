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

public struct LiveSessionSnapshot: Equatable, Sendable {
    public let sessionID: UUID?
    public let phase: LiveSessionPhase
    public let transcript: [TranscriptEntry]
    public let modelStatus: ModelRuntimeStatus?
    public let statusMessage: String

    public init(
        sessionID: UUID?,
        phase: LiveSessionPhase,
        transcript: [TranscriptEntry],
        modelStatus: ModelRuntimeStatus?,
        statusMessage: String
    ) {
        self.sessionID = sessionID
        self.phase = phase
        self.transcript = transcript
        self.modelStatus = modelStatus
        self.statusMessage = statusMessage
    }
}

public enum LiveSessionEvent: Equatable, Sendable {
    case stateChanged(LiveSessionSnapshot)
    case transcriptAppended(TranscriptEntry)
    case recoverableError(String)
}
