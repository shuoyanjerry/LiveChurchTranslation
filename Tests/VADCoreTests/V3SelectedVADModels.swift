import Foundation

struct V3SelectedVADFingerprint: Codable, Equatable, Sendable {
    let sha256: String
    let byteCount: Int64
}

struct V3SelectedVADSourceBundle: Codable, Equatable, Sendable {
    let sha256: String
    let fileCount: Int
}

struct V3SelectedVADProvenance: Codable, Equatable, Sendable {
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
    let preflightIdentitySHA256: String
    let postflightIdentitySHA256: String
}

struct V3SelectedVADReleaseGate: Codable, Equatable, Sendable {
    let humanLabelCount: Int
    let accuracyEligible: Bool
    let requiredGenuineSermonCount: Int
    let observedGenuineSermonCount: Int
    let genuineSermonCountGateMet: Bool
    let requiredGenuineAudioSeconds: Double
    let observedGenuineAudioSeconds: Double
    let genuineAudioDurationGateMet: Bool
    let releaseEligible: Bool
}

struct V3SelectedVADReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let evidenceKind: String
    let replayLane: String
    let decisionAuthority: String
    let labelAuthority: String
    let releaseStatus: String
    let provenance: V3SelectedVADProvenance
    let releaseGate: V3SelectedVADReleaseGate
    let caveats: [String]
    let attempts: [V3SelectedVADAttempt]
    let aggregates: V3SelectedVADAggregates
}
