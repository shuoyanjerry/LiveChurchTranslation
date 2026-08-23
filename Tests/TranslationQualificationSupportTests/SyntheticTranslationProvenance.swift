import TranslationQualificationSupport

extension SyntheticTranslationReportFactory {
    static func artifact(
        _ character: Character
    ) -> TranslationQualificationArtifactDigest {
        TranslationQualificationArtifactDigest(
            byteCount: 1,
            sha256: String(repeating: character, count: 64)
        )
    }

    static func bundle(
        _ character: Character
    ) -> TranslationQualificationBundleDigest {
        TranslationQualificationBundleDigest(
            format: TranslationExecutionProvenance.bundleFormat,
            entryCount: 1,
            byteCount: 1,
            sha256: String(repeating: character, count: 64)
        )
    }
}
