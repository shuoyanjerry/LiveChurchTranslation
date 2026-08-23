import Foundation

extension V3SelectedVADPreflight {
    func captureIdentity(
        inputs: V3SelectedVADInputs,
        manifest: V3SelectedVADManifest,
        tracks: [V3SelectedVADPreparedTrack],
        conversionPolicySHA256: String
    ) throws -> V3SelectedVADIdentitySnapshot {
        let implementation = try implementationIdentity(
            inputs: inputs,
            conversionPolicySHA256: conversionPolicySHA256
        )
        let corpus = try corpusSourceIdentity(inputs: inputs, manifest: manifest)
        return try makeIdentitySnapshot(
            inputs: inputs,
            tracks: tracks,
            conversionPolicySHA256: conversionPolicySHA256,
            implementation: implementation,
            corpus: corpus
        )
    }

    func validateDeclaredSources(
        _ manifest: V3SelectedVADManifest,
        sourceManifest: V3SelectedVADFingerprint,
        sourceSchema: V3SelectedVADFingerprint,
        builder: V3SelectedVADFingerprint
    ) throws {
        guard sourceManifest.sha256 == manifest.sourceManifest.sha256,
            sourceManifest.byteCount == manifest.sourceManifest.byteSize,
            sourceSchema.sha256 == manifest.sourceManifest.schemaSHA256,
            builder.sha256 == manifest.builder.sha256
        else { throw V3SelectedVADError.provenanceMismatch("corpus sources") }
    }
}
