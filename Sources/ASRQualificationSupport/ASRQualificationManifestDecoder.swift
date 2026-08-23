import Foundation

/// Strict JSON decoder that rejects unknown fields and returns only validated V2 manifests.
public struct ASRQualificationManifestDecoder: Sendable {
    public init() {}

    public func decode(_ data: Data) throws -> ASRQualificationManifestV2 {
        try StrictJSONDuplicateKeyValidator.validate(data)
        try StrictManifestShape.validate(data)
        let manifest: ASRQualificationManifestV2
        do {
            manifest = try JSONDecoder().decode(ASRQualificationManifestV2.self, from: data)
        } catch {
            throw ASRQualificationError.malformedManifest
        }
        try ASRQualificationManifestValidator().validate(manifest)
        return manifest
    }

    public func decode(contentsOf url: URL) throws -> ASRQualificationManifestV2 {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ASRQualificationError.manifestReadFailed(url.path)
        }
        return try decode(data)
    }
}

private enum StrictManifestShape {
    private static let rootKeys = ["schemaVersion", "corpusID", "provenance", "clips"]
    private static let provenanceKeys = [
        "sourceVADReportSHA256", "sourceVADStrategy", "sourceVADConfigurationSHA256",
        "sourceReferenceManifestSHA256", "sourceCorpusManifestSHA256", "generatorRevision",
    ]
    private static let clipKeys = [
        "id", "audioSHA256", "sampleRate", "totalSamples", "referenceSHA256",
        "allowsHypothesisEdgeInsertions", "segments",
    ]
    private static let segmentKeys = [
        "sequence", "startSample", "endSample", "validSampleCount",
        "syntheticPaddingSamples", "endReason", "pcmSHA256",
    ]

    static func validate(_ data: Data) throws {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ASRQualificationError.malformedManifest
        }
        guard let root = value as? [String: Any] else {
            throw ASRQualificationError.malformedManifest
        }
        try rejectUnknown(in: root, allowed: rootKeys, path: "$")
        if let provenance = root["provenance"] as? [String: Any] {
            try rejectUnknown(in: provenance, allowed: provenanceKeys, path: "provenance")
        }
        guard let clips = root["clips"] as? [Any] else { return }
        for (clipIndex, value) in clips.enumerated() {
            try validateClip(value, index: clipIndex)
        }
    }

    private static func validateClip(_ value: Any, index: Int) throws {
        guard let clip = value as? [String: Any] else { return }
        let path = "clips[\(index)]"
        try rejectUnknown(in: clip, allowed: clipKeys, path: path)
        guard let segments = clip["segments"] as? [Any] else { return }
        for (segmentIndex, value) in segments.enumerated() {
            guard let segment = value as? [String: Any] else { continue }
            try rejectUnknown(
                in: segment,
                allowed: segmentKeys,
                path: "\(path).segments[\(segmentIndex)]"
            )
        }
    }

    private static func rejectUnknown(
        in object: [String: Any],
        allowed: [String],
        path: String
    ) throws {
        let allowedKeys = Set(allowed)
        guard let field = object.keys.sorted().first(where: { !allowedKeys.contains($0) }) else {
            return
        }
        throw ASRQualificationError.unexpectedField(path: path, field: field)
    }
}
