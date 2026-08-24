import Foundation

public struct RemoteProjectionEnvelope: Equatable, Codable, Sendable {
    public let protocolVersion: UInt16
    public let messageID: UUID
    public let payload: Payload

    public init(
        protocolVersion: UInt16 = 1,
        messageID: UUID = UUID(),
        payload: Payload
    ) {
        self.protocolVersion = protocolVersion
        self.messageID = messageID
        self.payload = payload
    }

    public enum Payload: Equatable, Codable, Sendable {
        case snapshot(RemoteProjectionSnapshot)
        case entryUpsert(sessionID: UUID, entry: RemoteTranscriptEntry, revision: UInt64)
        case stateChanged(
            sessionID: UUID?,
            phase: RemoteSessionPhase,
            message: String,
            sourceLanguage: String?,
            targetLanguage: String?,
            revision: UInt64
        )
        case resyncRequired(latestRevision: UInt64)
        case heartbeat(revision: UInt64)

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: ProjectionPayloadCodingKey.self)
            switch try values.decode(ProjectionPayloadKind.self, forKey: .type) {
            case .snapshot:
                self = .snapshot(try values.decode(RemoteProjectionSnapshot.self, forKey: .snapshot))
            case .entryUpsert:
                self = .entryUpsert(
                    sessionID: try values.decode(UUID.self, forKey: .sessionID),
                    entry: try values.decode(RemoteTranscriptEntry.self, forKey: .entry),
                    revision: try values.decode(UInt64.self, forKey: .revision)
                )
            case .stateChanged:
                self = .stateChanged(
                    sessionID: try values.decodeIfPresent(UUID.self, forKey: .sessionID),
                    phase: try values.decode(RemoteSessionPhase.self, forKey: .phase),
                    message: try values.decode(String.self, forKey: .message),
                    sourceLanguage: try values.decodeIfPresent(
                        String.self,
                        forKey: .sourceLanguage
                    ),
                    targetLanguage: try values.decodeIfPresent(
                        String.self,
                        forKey: .targetLanguage
                    ),
                    revision: try values.decode(UInt64.self, forKey: .revision)
                )
            case .resyncRequired:
                self = .resyncRequired(
                    latestRevision: try values.decode(UInt64.self, forKey: .latestRevision)
                )
            case .heartbeat:
                self = .heartbeat(revision: try values.decode(UInt64.self, forKey: .revision))
            }
        }

        public func encode(to encoder: any Encoder) throws {
            var values = encoder.container(keyedBy: ProjectionPayloadCodingKey.self)
            switch self {
            case .snapshot(let snapshot):
                try values.encode(ProjectionPayloadKind.snapshot, forKey: .type)
                try values.encode(snapshot, forKey: .snapshot)
            case .entryUpsert(let sessionID, let entry, let revision):
                try values.encode(ProjectionPayloadKind.entryUpsert, forKey: .type)
                try values.encode(sessionID, forKey: .sessionID)
                try values.encode(entry, forKey: .entry)
                try values.encode(revision, forKey: .revision)
            case .stateChanged(
                let sessionID,
                let phase,
                let message,
                let sourceLanguage,
                let targetLanguage,
                let revision
            ):
                try values.encode(ProjectionPayloadKind.stateChanged, forKey: .type)
                try values.encodeIfPresent(sessionID, forKey: .sessionID)
                try values.encode(phase, forKey: .phase)
                try values.encode(message, forKey: .message)
                try values.encodeIfPresent(sourceLanguage, forKey: .sourceLanguage)
                try values.encodeIfPresent(targetLanguage, forKey: .targetLanguage)
                try values.encode(revision, forKey: .revision)
            case .resyncRequired(let latestRevision):
                try values.encode(ProjectionPayloadKind.resyncRequired, forKey: .type)
                try values.encode(latestRevision, forKey: .latestRevision)
            case .heartbeat(let revision):
                try values.encode(ProjectionPayloadKind.heartbeat, forKey: .type)
                try values.encode(revision, forKey: .revision)
            }
        }
    }
}

private enum ProjectionPayloadKind: String, Codable {
    case snapshot
    case entryUpsert
    case stateChanged
    case resyncRequired
    case heartbeat
}

private enum ProjectionPayloadCodingKey: String, CodingKey {
    case type
    case snapshot
    case sessionID
    case entry
    case phase
    case message
    case sourceLanguage
    case targetLanguage
    case revision
    case latestRevision
}
