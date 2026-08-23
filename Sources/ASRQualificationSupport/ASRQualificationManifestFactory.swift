/// Pure construction helpers for producer-side manifest freezing.
public enum ASRQualificationManifestFactory {
    public static func make(
        corpusID: String,
        provenance: ASRQualificationProvenanceV2,
        clips: [ASRQualificationClipV2]
    ) throws -> ASRQualificationManifestV2 {
        let manifest = ASRQualificationManifestV2(
            schemaVersion: 2,
            corpusID: corpusID,
            provenance: provenance,
            clips: clips
        )
        try ASRQualificationManifestValidator().validate(manifest)
        return manifest
    }
}
