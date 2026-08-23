import Foundation

enum ManifestToolConsistency {
    static func index<T>(
        _ values: [T],
        source: String,
        id: (T) throws -> String
    ) throws -> [String: T] {
        var result: [String: T] = [:]
        for value in values {
            let identifier = try id(value)
            guard !identifier.isEmpty, !identifier.allSatisfy(\.isWhitespace) else {
                throw ManifestToolError.invalidValue(path: "\(source).id")
            }
            guard result[identifier] == nil else {
                throw ManifestToolError.duplicateID(source: source, id: identifier)
            }
            result[identifier] = value
        }
        return result
    }

    static func validateSources(
        corpus: CorpusManifest,
        reference: ReferenceManifest
    ) throws -> ([String: CorpusClip], [String: ReferenceClip]) {
        guard corpus.corpusID == reference.corpusID,
            !corpus.corpusID.allSatisfy(\.isWhitespace)
        else {
            throw ManifestToolError.corpusIDMismatch
        }
        let corpusClips = try index(corpus.clips, source: "corpus") { $0.id }
        let referenceClips = try index(reference.clips, source: "reference") { $0.id }
        guard Set(corpusClips.keys) == Set(referenceClips.keys) else {
            throw ManifestToolError.clipSetMismatch(source: "reference")
        }
        for (id, clip) in corpusClips {
            guard let referenceClip = referenceClips[id] else {
                throw ManifestToolError.clipSetMismatch(source: "reference")
            }
            guard clip.referenceText == referenceClip.referenceText else {
                throw ManifestToolError.referenceTextMismatch(id)
            }
            guard clip.referenceSegments == referenceClip.referenceSegments,
                clip.durationMilliseconds == referenceClip.durationMilliseconds
            else {
                throw ManifestToolError.referenceMetadataMismatch(id)
            }
        }
        return (corpusClips, referenceClips)
    }

    static func clipID(fileName: String) throws -> String {
        let url = URL(fileURLWithPath: fileName)
        guard url.lastPathComponent == fileName,
            url.pathExtension == "wav"
        else {
            throw ManifestToolError.invalidVADFile(fileName)
        }
        let id = url.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { throw ManifestToolError.invalidVADFile(fileName) }
        return id
    }
}
