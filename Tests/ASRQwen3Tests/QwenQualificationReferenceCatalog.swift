import ASRQualificationSupport
import Foundation

struct QwenQualificationReferenceCatalog: Equatable {
    let referencesByID: [String: String]

    static func load(
        from url: URL,
        for manifest: ASRQualificationManifestV2
    ) throws -> Self {
        try load(
            data: Data(contentsOf: url, options: .mappedIfSafe),
            for: manifest
        )
    }

    static func load(
        data: Data,
        for manifest: ASRQualificationManifestV2
    ) throws -> Self {
        let actualSHA = QwenQualificationHashing.sha256(data)
        guard actualSHA == manifest.provenance.sourceReferenceManifestSHA256 else {
            throw QwenQualificationReferenceError.sha256Mismatch
        }
        let source: ReferenceManifest
        do {
            source = try JSONDecoder().decode(ReferenceManifest.self, from: data)
        } catch {
            throw QwenQualificationReferenceError.malformedManifest
        }
        guard source.schemaVersion == 1 else {
            throw QwenQualificationReferenceError.unsupportedSchema(source.schemaVersion)
        }
        guard source.corpusID == manifest.corpusID else {
            throw QwenQualificationReferenceError.corpusMismatch
        }
        return try make(source.clips, expectedIDs: manifest.clips.map(\.id))
    }

    private static func make(
        _ clips: [ReferenceClip],
        expectedIDs: [String]
    ) throws -> Self {
        var references: [String: String] = [:]
        for clip in clips {
            guard references.updateValue(clip.referenceText, forKey: clip.id) == nil else {
                throw QwenQualificationReferenceError.duplicateClipID(clip.id)
            }
        }
        guard references.keys.sorted() == expectedIDs.sorted() else {
            throw QwenQualificationReferenceError.clipSetMismatch
        }
        return Self(referencesByID: references)
    }
}

enum QwenQualificationReferenceError: Error, Equatable {
    case sha256Mismatch
    case malformedManifest
    case unsupportedSchema(Int)
    case corpusMismatch
    case duplicateClipID(String)
    case clipSetMismatch
}

private struct ReferenceManifest: Decodable {
    let schemaVersion: Int
    let corpusID: String
    let clips: [ReferenceClip]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case corpusID = "corpus_id"
        case clips
    }
}

private struct ReferenceClip: Decodable {
    let id: String
    let referenceText: String

    enum CodingKeys: String, CodingKey {
        case id
        case referenceText = "reference_text"
    }
}
