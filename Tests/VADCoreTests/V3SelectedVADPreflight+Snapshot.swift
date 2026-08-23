import Foundation

extension V3SelectedVADPreflight {
    func makeIdentitySnapshot(
        inputs: V3SelectedVADInputs,
        tracks: [V3SelectedVADPreparedTrack],
        conversionPolicySHA256: String,
        implementation: V3SelectedVADImplementationIdentity,
        corpus: V3SelectedVADCorpusSourceIdentity
    ) throws -> V3SelectedVADIdentitySnapshot {
        V3SelectedVADIdentitySnapshot(
            replayManifest: try V3SelectedVADHashing.fingerprint(inputs.manifestURL),
            validationSidecar: try V3SelectedVADHashing.fingerprint(inputs.validationURL),
            sourceManifest: corpus.manifest,
            sourceManifestSchema: corpus.schema,
            corpusBuilder: corpus.builder,
            conversionPolicySHA256: conversionPolicySHA256,
            selectedConfigurationSHA256: try V3SelectedVADHashing.canonicalDigest(
                V3SelectedVADConfigurationEvidence.selected()
            ),
            productionSourceBundle: implementation.production,
            harnessSourceBundle: implementation.harness,
            packageManifest: implementation.packageManifest,
            packageResolved: implementation.packageResolved,
            loadedReleaseTestExecutable: implementation.releaseExecutable,
            wavSetSHA256: try wavSetDigest(tracks)
        )
    }
}
