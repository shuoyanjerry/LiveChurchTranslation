import Foundation
import PersistenceAPI
import TranscriptAPI

struct SessionManifest: Codable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let entryCount: Int
    let title: String?
    let kind: TranscriptSessionKind
    let sourceLanguage: String
    let targetLanguage: String
    let integrity: StoredTranscriptIntegrity
    let pendingRecordCount: Int
    let rejections: [StoredTranscriptRejection]
    let quarantinedArtifactCount: Int
    let hasUnrecoverableFailure: Bool

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, entryCount, title, kind, sourceLanguage, targetLanguage
        case integrity, pendingRecordCount, rejections, quarantinedArtifactCount
        case hasUnrecoverableFailure
    }

    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date?,
        entryCount: Int,
        title: String?,
        kind: TranscriptSessionKind,
        sourceLanguage: String,
        targetLanguage: String,
        integrity: StoredTranscriptIntegrity,
        pendingRecordCount: Int = 0,
        rejections: [StoredTranscriptRejection] = [],
        quarantinedArtifactCount: Int = 0,
        hasUnrecoverableFailure: Bool = false
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entryCount = entryCount
        self.title = title
        self.kind = kind
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.integrity = integrity
        self.pendingRecordCount = pendingRecordCount
        self.rejections = rejections
        self.quarantinedArtifactCount = quarantinedArtifactCount
        self.hasUnrecoverableFailure = hasUnrecoverableFailure
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
        entryCount = try values.decode(Int.self, forKey: .entryCount)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        kind = try values.decodeIfPresent(TranscriptSessionKind.self, forKey: .kind) ?? .live
        sourceLanguage =
            try values.decodeIfPresent(String.self, forKey: .sourceLanguage)
            ?? "zh-Hans"
        targetLanguage = try values.decodeIfPresent(String.self, forKey: .targetLanguage) ?? "en"
        integrity =
            try values.decodeIfPresent(StoredTranscriptIntegrity.self, forKey: .integrity)
            ?? (endedAt == nil ? .active : .complete)
        let decodedPendingCount =
            try values.decodeIfPresent(Int.self, forKey: .pendingRecordCount) ?? 0
        rejections =
            try values.decodeIfPresent([StoredTranscriptRejection].self, forKey: .rejections)
            ?? []
        let decodedQuarantineCount =
            try values.decodeIfPresent(Int.self, forKey: .quarantinedArtifactCount) ?? 0
        guard decodedPendingCount >= 0, decodedQuarantineCount >= 0 else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: values.codingPath,
                    debugDescription: "Session recovery counts cannot be negative."
                )
            )
        }
        pendingRecordCount = decodedPendingCount
        quarantinedArtifactCount = decodedQuarantineCount
        hasUnrecoverableFailure =
            try values.decodeIfPresent(Bool.self, forKey: .hasUnrecoverableFailure) ?? false
    }
}

extension SessionManifest {
    var finalization: TranscriptFinalization {
        TranscriptFinalization(
            pendingRecordCount: pendingRecordCount,
            rejections: rejections,
            quarantinedArtifactCount: quarantinedArtifactCount,
            hasUnrecoverableFailure: hasUnrecoverableFailure
        )
    }
}
