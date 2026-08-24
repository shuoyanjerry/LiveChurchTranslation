import Foundation
import PersistenceAPI
import TranscriptAPI

enum StoredTranscriptContentPolicy: String, Codable, Sendable {
    case legacyBilingual
    case sourceOnly
}

struct SessionManifest: Codable, Sendable {
    static let legacySchemaVersion = 1
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let contentPolicy: StoredTranscriptContentPolicy
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

    fileprivate enum CodingKeys: String, CodingKey {
        case schemaVersion, contentPolicy
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
        schemaVersion = Self.currentSchemaVersion
        contentPolicy = .sourceOnly
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
        let format = try Self.decodeStorageFormat(from: values)
        schemaVersion = format.schemaVersion
        contentPolicy = format.contentPolicy
        id = try values.decode(UUID.self, forKey: .id)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
        entryCount = try values.decode(Int.self, forKey: .entryCount)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        kind = try values.decodeIfPresent(TranscriptSessionKind.self, forKey: .kind) ?? .live
        sourceLanguage = try values.decodeIfPresent(String.self, forKey: .sourceLanguage) ?? "zh-Hans"
        targetLanguage = try values.decodeIfPresent(String.self, forKey: .targetLanguage) ?? "en"
        integrity =
            try values.decodeIfPresent(StoredTranscriptIntegrity.self, forKey: .integrity)
            ?? (endedAt == nil ? .active : .complete)
        let pendingCount = try values.decodeIfPresent(Int.self, forKey: .pendingRecordCount) ?? 0
        rejections =
            try values.decodeIfPresent(
                [StoredTranscriptRejection].self,
                forKey: .rejections
            ) ?? []
        let quarantineCount =
            try values.decodeIfPresent(
                Int.self,
                forKey: .quarantinedArtifactCount
            ) ?? 0
        try Self.validateRecoveryCounts(pendingCount, quarantineCount, codingPath: values.codingPath)
        pendingRecordCount = pendingCount
        quarantinedArtifactCount = quarantineCount
        hasUnrecoverableFailure =
            try values.decodeIfPresent(Bool.self, forKey: .hasUnrecoverableFailure) ?? false
    }

}

extension SessionManifest {
    fileprivate static func decodeStorageFormat(
        from values: KeyedDecodingContainer<CodingKeys>
    ) throws -> DecodedStorageFormat {
        let decodedSchemaVersion =
            try values.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.legacySchemaVersion
        let decodedContentPolicy =
            try values.decodeIfPresent(StoredTranscriptContentPolicy.self, forKey: .contentPolicy)
            ?? (decodedSchemaVersion == Self.legacySchemaVersion ? .legacyBilingual : .sourceOnly)
        guard
            (decodedSchemaVersion == Self.legacySchemaVersion
                && decodedContentPolicy == .legacyBilingual)
                || (decodedSchemaVersion == Self.currentSchemaVersion
                    && decodedContentPolicy == .sourceOnly)
        else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: values.codingPath,
                    debugDescription: "Unsupported transcript storage schema or content policy."
                )
            )
        }
        return DecodedStorageFormat(
            schemaVersion: decodedSchemaVersion,
            contentPolicy: decodedContentPolicy
        )
    }

    fileprivate static func validateRecoveryCounts(
        _ pendingCount: Int,
        _ quarantineCount: Int,
        codingPath: [any CodingKey]
    ) throws {
        guard pendingCount >= 0, quarantineCount >= 0 else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: codingPath,
                    debugDescription: "Session recovery counts cannot be negative."
                )
            )
        }
    }
}

private struct DecodedStorageFormat {
    let schemaVersion: Int
    let contentPolicy: StoredTranscriptContentPolicy
}

extension SessionManifest {
    var storesSourceOnlyEntries: Bool {
        schemaVersion == Self.currentSchemaVersion && contentPolicy == .sourceOnly
    }

    var finalization: TranscriptFinalization {
        TranscriptFinalization(
            pendingRecordCount: pendingRecordCount,
            rejections: rejections,
            quarantinedArtifactCount: quarantinedArtifactCount,
            hasUnrecoverableFailure: hasUnrecoverableFailure
        )
    }
}
