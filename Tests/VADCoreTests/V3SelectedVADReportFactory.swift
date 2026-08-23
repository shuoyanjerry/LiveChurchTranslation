import Foundation

enum V3SelectedVADReportFactory {
    static func make(
        prepared: V3SelectedVADPreparedCorpus,
        postflight: V3SelectedVADIdentitySnapshot,
        attempts: [V3SelectedVADAttempt]
    ) throws -> V3SelectedVADReport {
        let aggregates = V3SelectedVADAggregateBuilder.make(attempts)
        let genuine = aggregates.genuineChurchSermons
        return V3SelectedVADReport(
            schemaVersion: 1,
            evidenceKind: "manifest-aware-selected-webrtc-vad-shadow-baseline",
            replayLane: "webrtcStable",
            decisionAuthority: "none",
            labelAuthority: "none",
            releaseStatus: "no-go",
            provenance: try provenance(prepared.identity, postflight: postflight),
            releaseGate: V3SelectedVADReleaseGate(
                humanLabelCount: 0,
                accuracyEligible: false,
                requiredGenuineSermonCount: 12,
                observedGenuineSermonCount: genuine.logicalItemCount,
                genuineSermonCountGateMet: genuine.logicalItemCount >= 12,
                requiredGenuineAudioSeconds: 28_800,
                observedGenuineAudioSeconds: genuine.expectedAudioSeconds,
                genuineAudioDurationGateMet: genuine.expectedAudioSeconds >= 28_800,
                releaseEligible: false
            ),
            caveats: caveats,
            attempts: attempts,
            aggregates: aggregates
        )
    }

    private static func provenance(
        _ identity: V3SelectedVADIdentitySnapshot,
        postflight: V3SelectedVADIdentitySnapshot
    ) throws -> V3SelectedVADProvenance {
        try V3SelectedVADProvenance(
            replayManifest: identity.replayManifest,
            validationSidecar: identity.validationSidecar,
            sourceManifest: identity.sourceManifest,
            sourceManifestSchema: identity.sourceManifestSchema,
            corpusBuilder: identity.corpusBuilder,
            conversionPolicySHA256: identity.conversionPolicySHA256,
            selectedConfigurationSHA256: identity.selectedConfigurationSHA256,
            productionSourceBundle: identity.productionSourceBundle,
            harnessSourceBundle: identity.harnessSourceBundle,
            packageManifest: identity.packageManifest,
            packageResolved: identity.packageResolved,
            loadedReleaseTestExecutable: identity.loadedReleaseTestExecutable,
            wavSetSHA256: identity.wavSetSHA256,
            preflightIdentitySHA256: identity.digest,
            postflightIdentitySHA256: postflight.digest
        )
    }

    private static let caveats = [
        "Shadow evidence never changes, vetoes, or promotes a production endpoint decision.",
        "There are no independent human boundary labels, so this report has no accuracy authority.",
        "The eight genuine sermon items remain separate from 120 scripted or narration tracks.",
        "Genuine coverage is below both the 12-sermon and eight-hour release requirements.",
        "Hard-cut and short-segment counts are structural proxies, not human correctness labels.",
        "Host-dependent execution time is intentionally excluded and is not an end-to-end SLA.",
    ]
}
