import Foundation

struct V3SelectedVADImplementationIdentity {
    let production: V3SelectedVADSourceBundle
    let harness: V3SelectedVADSourceBundle
    let packageManifest: V3SelectedVADFingerprint
    let packageResolved: V3SelectedVADFingerprint
    let releaseExecutable: V3SelectedVADFingerprint
}

struct V3SelectedVADCorpusSourceIdentity {
    let manifest: V3SelectedVADFingerprint
    let schema: V3SelectedVADFingerprint
    let builder: V3SelectedVADFingerprint
}

extension V3SelectedVADPreflight {
    func implementationIdentity(
        inputs: V3SelectedVADInputs,
        conversionPolicySHA256: String
    ) throws -> V3SelectedVADImplementationIdentity {
        let production = try V3SelectedVADSourceFingerprints.production(
            workspaceRoot: inputs.workspaceRoot
        )
        let packageManifest = try V3SelectedVADHashing.fingerprint(
            inputs.workspaceRoot.appendingPathComponent("Package.swift")
        )
        let packageResolved = try V3SelectedVADHashing.fingerprint(
            inputs.workspaceRoot.appendingPathComponent("Package.resolved")
        )
        guard production.fileCount == 59,
            production.sha256 == V3SelectedVADPolicy.productionSourceSHA256,
            packageManifest.sha256 == V3SelectedVADPolicy.packageManifestSHA256,
            packageResolved.sha256 == V3SelectedVADPolicy.packageResolvedSHA256,
            conversionPolicySHA256 == V3SelectedVADPolicy.conversionPolicySHA256
        else { throw V3SelectedVADError.provenanceMismatch("implementation snapshot") }
        return V3SelectedVADImplementationIdentity(
            production: production,
            harness: try V3SelectedVADSourceFingerprints.harness(
                workspaceRoot: inputs.workspaceRoot
            ),
            packageManifest: packageManifest,
            packageResolved: packageResolved,
            releaseExecutable: try V3SelectedVADReleaseExecutable.fingerprint()
        )
    }

    func corpusSourceIdentity(
        inputs: V3SelectedVADInputs,
        manifest: V3SelectedVADManifest
    ) throws -> V3SelectedVADCorpusSourceIdentity {
        let result = V3SelectedVADCorpusSourceIdentity(
            manifest: try V3SelectedVADHashing.fingerprint(inputs.sourceManifestURL),
            schema: try V3SelectedVADHashing.fingerprint(inputs.sourceSchemaURL),
            builder: try V3SelectedVADHashing.fingerprint(inputs.builderURL)
        )
        try validateDeclaredSources(
            manifest,
            sourceManifest: result.manifest,
            sourceSchema: result.schema,
            builder: result.builder
        )
        return result
    }
}
