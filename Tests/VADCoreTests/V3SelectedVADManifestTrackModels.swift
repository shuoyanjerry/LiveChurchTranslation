import Foundation

struct V3SelectedVADManifestItem: Decodable {
    let itemID: String
    let itemClass: V3SelectedVADSceneClass
    let trackCount: Int
    let concatenated: Bool
    let tracks: [V3SelectedVADManifestTrack]
}

struct V3SelectedVADManifestTrack: Decodable {
    let itemID: String
    let ordinal: Int
    let relativeWAVPath: String
    let convertedWAVSHA256: String
    let convertedWAVByteSize: Int64
    let exactSampleFrames: Int64
    let exactDurationSeconds: Double
    let pcmDataByteSize: Int64
    let resetStateBeforeTrack: Bool
    let emitEndOfStreamAfterTrack: Bool
    let allowContinuationFromPreviousTrack: Bool
}

struct V3SelectedVADValidationSidecar: Decodable {
    let schemaVersion: Int
    let manifestSHA256: String
    let sourceManifestSHA256: String
    let logicalItemCount: Int
    let trackCount: Int
    let genuineChurchSermonItemCount: Int
    let scriptedOrNarrationProgramItemCount: Int
    let decodedDurationSeconds: Double
    let exactSampleFrames: Int64
    let outputRootMode: String
    let fileMode: String
    let releaseSermonCountGateMet: Bool
    let forbiddenExactTextFieldCount: Int
    let sourceInputValidationErrorCount: Int
    let wavValidationErrorCount: Int
    let durationValidationErrorCount: Int
    let symlinkCount: Int
    let replicaCount: Int
    let allThreeFullReplayReplicasByteIdentical: Bool
}

struct V3SelectedVADPreparedTrack: Sendable {
    let logicalItemOrdinal: Int
    let trackOrdinal: Int
    let sceneClass: V3SelectedVADSceneClass
    let url: URL
    let expected: V3SelectedVADManifestTrack
    let fingerprint: V3SelectedVADFingerprint
}
