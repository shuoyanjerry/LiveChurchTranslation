import Foundation

struct V3SelectedVADManifest: Decodable {
    let schemaVersion: Int
    let manifestKind: String
    let visibility: String
    let containsTranscriptText: Bool
    let containsTitleSpeakerURLOrSceneText: Bool
    let sourceManifest: V3SelectedVADManifestSource
    let builder: V3SelectedVADManifestBuilder
    let conversionPolicySHA256: String
    let audioFormat: V3SelectedVADAudioFormat
    let replaySemantics: V3SelectedVADReplaySemantics
    let summary: V3SelectedVADManifestSummary
    let sceneClassAggregate: [V3SelectedVADSceneAggregate]
    let items: [V3SelectedVADManifestItem]
}

struct V3SelectedVADManifestSource: Decodable {
    let sha256: String
    let byteSize: Int64
    let schemaVersion: Int
    let schemaSHA256: String
}

struct V3SelectedVADManifestBuilder: Decodable {
    let sha256: String
}

struct V3SelectedVADAudioFormat: Decodable {
    let sampleRateHz: Int
    let channels: Int
    let sampleWidthBytes: Int
    let encoding: String
}

struct V3SelectedVADReplaySemantics: Decodable {
    let trackOrder: String
    let resetStateBeforeEveryTrack: Bool
    let emitEndOfStreamAfterEveryTrack: Bool
    let allowCrossTrackContinuation: Bool
    let interTrackGapSamples: Int
    let concatenateTracks: Bool
}

struct V3SelectedVADManifestSummary: Decodable {
    let logicalItemCount: Int
    let genuineChurchSermonItemCount: Int
    let scriptedOrNarrationProgramItemCount: Int
    let trackCount: Int
    let exactDecodedSampleFrames: Int64
    let exactDecodedDurationSeconds: Double
    let releaseSermonCountGateMet: Bool
}

struct V3SelectedVADSceneAggregate: Decodable {
    let itemClass: V3SelectedVADSceneClass
    let logicalItemCount: Int
    let trackCount: Int
    let exactSampleFrames: Int64
    let exactDurationSeconds: Double
}
