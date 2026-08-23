/// Validates all Manifest V2 semantic invariants without performing I/O.
public struct ASRQualificationManifestValidator: Sendable {
    public init() {}

    public func validate(_ manifest: ASRQualificationManifestV2) throws {
        try ASRQualificationManifestRules.validate(manifest)
    }
}

enum ASRQualificationManifestRules {
    static func validate(_ manifest: ASRQualificationManifestV2) throws {
        guard manifest.schemaVersion == 2 else {
            throw ASRQualificationError.unsupportedSchemaVersion(manifest.schemaVersion)
        }
        guard !ASRQualificationScalarRules.isBlank(manifest.corpusID) else {
            throw ASRQualificationError.emptyCorpusID
        }
        try ASRQualificationProvenanceRules.validate(manifest.provenance)
        guard !manifest.clips.isEmpty else {
            throw ASRQualificationError.emptyClips
        }
        var identifiers = Set<String>()
        for (index, clip) in manifest.clips.enumerated() {
            try validate(clip, index: index)
            guard identifiers.insert(clip.id).inserted else {
                throw ASRQualificationError.duplicateClipID(clip.id)
            }
        }
    }

    static func validate(_ clip: ASRQualificationClipV2, index: Int? = nil) throws {
        guard !ASRQualificationScalarRules.isBlank(clip.id) else {
            throw ASRQualificationError.invalidClipID(index: index ?? 0)
        }
        guard clip.sampleRate > 0 else {
            throw ASRQualificationError.invalidSampleRate(
                clipID: clip.id,
                value: clip.sampleRate
            )
        }
        guard clip.totalSamples > 0 else {
            throw ASRQualificationError.invalidTotalSamples(
                clipID: clip.id,
                value: clip.totalSamples
            )
        }
        try ASRQualificationScalarRules.validateHash(
            clip.audioSHA256,
            path: "\(clip.id).audioSHA256"
        )
        try ASRQualificationScalarRules.validateHash(
            clip.referenceSHA256,
            path: "\(clip.id).referenceSHA256"
        )
        guard !clip.segments.isEmpty else {
            throw ASRQualificationError.emptySegments(clipID: clip.id)
        }
        try ASRQualificationSegmentRules.validate(clip)
    }
}
