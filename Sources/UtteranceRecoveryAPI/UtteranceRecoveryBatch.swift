import Foundation

/// Why an unreadable pending artifact was isolated instead of retried.
public enum UtteranceQuarantineReason: String, Sendable, Equatable, Codable {
    case incompleteWrite
    case malformedMetadata
    case unsupportedSchema
    case malformedAudio
    case metadataMismatch
    case oversizedArtifact
    case orphanedArtifact
}

/// Non-sensitive evidence that a pending artifact was moved out of service.
public struct QuarantinedUtterance: Sendable, Equatable {
    public let sessionID: UUID?
    public let originalName: String
    public let reason: UtteranceQuarantineReason
    public let quarantinedAt: Date

    public init(
        sessionID: UUID? = nil,
        originalName: String,
        reason: UtteranceQuarantineReason,
        quarantinedAt: Date
    ) {
        self.sessionID = sessionID
        self.originalName = originalName
        self.reason = reason
        self.quarantinedAt = quarantinedAt
    }
}

/// Results of one recovery scan, ordered by utterance sequence.
public struct UtteranceRecoveryBatch: Sendable, Equatable {
    public let pending: [PendingUtteranceRecord]
    public let quarantined: [QuarantinedUtterance]

    public init(
        pending: [PendingUtteranceRecord],
        quarantined: [QuarantinedUtterance]
    ) {
        self.pending = pending
        self.quarantined = quarantined
    }
}
