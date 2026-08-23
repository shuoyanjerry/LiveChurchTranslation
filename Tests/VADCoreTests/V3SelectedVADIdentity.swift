import Foundation

struct V3SelectedVADIdentitySnapshot: Codable, Equatable {
    let replayManifest: V3SelectedVADFingerprint
    let validationSidecar: V3SelectedVADFingerprint
    let sourceManifest: V3SelectedVADFingerprint
    let sourceManifestSchema: V3SelectedVADFingerprint
    let corpusBuilder: V3SelectedVADFingerprint
    let conversionPolicySHA256: String
    let selectedConfigurationSHA256: String
    let productionSourceBundle: V3SelectedVADSourceBundle
    let harnessSourceBundle: V3SelectedVADSourceBundle
    let packageManifest: V3SelectedVADFingerprint
    let packageResolved: V3SelectedVADFingerprint
    let loadedReleaseTestExecutable: V3SelectedVADFingerprint
    let wavSetSHA256: String

    var digest: String {
        get throws { try V3SelectedVADHashing.canonicalDigest(self) }
    }
}

struct V3SelectedVADPreparedCorpus {
    let manifest: V3SelectedVADManifest
    let validation: V3SelectedVADValidationSidecar
    let tracks: [V3SelectedVADPreparedTrack]
    let identity: V3SelectedVADIdentitySnapshot
    let forbiddenValues: [String]
}
