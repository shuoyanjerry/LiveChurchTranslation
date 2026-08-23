import ASRQualificationSupport
import Foundation

struct FunQualificationReferenceCatalog: Equatable {
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
        guard
            FunQualificationHashing.sha256(data)
                == manifest.provenance.sourceReferenceManifestSHA256
        else {
            throw FunQualificationReferenceError.sha256Mismatch
        }
        let source: ReferenceManifest
        do {
            source = try JSONDecoder().decode(ReferenceManifest.self, from: data)
        } catch {
            throw FunQualificationReferenceError.malformedManifest
        }
        guard source.schemaVersion == 1 else {
            throw FunQualificationReferenceError.unsupportedSchema(source.schemaVersion)
        }
        guard source.corpusID == manifest.corpusID else {
            throw FunQualificationReferenceError.corpusMismatch
        }
        return try make(source.clips, manifestClips: manifest.clips)
    }

    private static func make(
        _ clips: [ReferenceClip],
        manifestClips: [ASRQualificationClipV2]
    ) throws -> Self {
        var references: [String: String] = [:]
        for clip in clips {
            guard references.updateValue(clip.referenceText, forKey: clip.id) == nil else {
                throw FunQualificationReferenceError.duplicateClipID(clip.id)
            }
        }
        guard references.keys.sorted() == manifestClips.map(\.id).sorted() else {
            throw FunQualificationReferenceError.clipSetMismatch
        }
        for clip in manifestClips {
            let text = references[clip.id] ?? ""
            guard FunQualificationHashing.sha256(Data(text.utf8)) == clip.referenceSHA256 else {
                throw FunQualificationReferenceError.referenceSHA256Mismatch(clip.id)
            }
        }
        return Self(referencesByID: references)
    }
}

enum FunQualificationReferenceError: Error, Equatable {
    case sha256Mismatch
    case malformedManifest
    case unsupportedSchema(Int)
    case corpusMismatch
    case duplicateClipID(String)
    case clipSetMismatch
    case referenceSHA256Mismatch(String)
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
