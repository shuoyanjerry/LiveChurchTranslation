import Foundation

struct V3SelectedVADPreflight {
    func prepare(_ inputs: V3SelectedVADInputs) throws -> V3SelectedVADPreparedCorpus {
        let manifestFingerprint = try V3SelectedVADHashing.fingerprint(inputs.manifestURL)
        let validationFingerprint = try V3SelectedVADHashing.fingerprint(inputs.validationURL)
        guard manifestFingerprint.sha256 == V3SelectedVADPolicy.manifestSHA256,
            validationFingerprint.sha256 == V3SelectedVADPolicy.validationSHA256
        else { throw V3SelectedVADError.provenanceMismatch("frozen corpus documents") }
        let manifestData = try Data(contentsOf: inputs.manifestURL, options: [.uncached])
        let validationData = try Data(contentsOf: inputs.validationURL, options: [.uncached])
        let manifest = try JSONDecoder().decode(V3SelectedVADManifest.self, from: manifestData)
        let validation = try JSONDecoder().decode(
            V3SelectedVADValidationSidecar.self,
            from: validationData
        )
        try V3SelectedVADManifestValidator.validate(manifest, validation: validation)
        try validatePrivateDocumentPermissions(inputs)
        let tracks = try prepareTracks(manifest.items, inputs: inputs)
        let identity = try captureIdentity(
            inputs: inputs,
            manifest: manifest,
            tracks: tracks,
            conversionPolicySHA256: try conversionPolicyDigest(manifestData)
        )
        return V3SelectedVADPreparedCorpus(
            manifest: manifest,
            validation: validation,
            tracks: tracks,
            identity: identity,
            forbiddenValues: forbiddenValues(manifest: manifest, inputs: inputs)
        )
    }

    func revalidate(
        _ prepared: V3SelectedVADPreparedCorpus,
        inputs: V3SelectedVADInputs
    ) throws -> V3SelectedVADIdentitySnapshot {
        let manifestData = try Data(contentsOf: inputs.manifestURL, options: [.uncached])
        let identity = try captureIdentity(
            inputs: inputs,
            manifest: prepared.manifest,
            tracks: prepared.tracks,
            conversionPolicySHA256: try conversionPolicyDigest(manifestData)
        )
        guard identity == prepared.identity else { throw V3SelectedVADError.unsafeInput }
        return identity
    }
}
