import Foundation

extension V3SelectedVADManifest {
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case manifestKind = "manifest_kind"
        case visibility
        case containsTranscriptText = "contains_transcript_text"
        case containsTitleSpeakerURLOrSceneText = "contains_title_speaker_url_or_scene_text"
        case sourceManifest = "source_manifest"
        case builder
        case conversionPolicySHA256 = "conversion_policy_sha256"
        case audioFormat = "audio_format"
        case replaySemantics = "replay_semantics"
        case summary
        case sceneClassAggregate = "scene_class_aggregate"
        case items
    }
}

extension V3SelectedVADManifestSource {
    enum CodingKeys: String, CodingKey {
        case sha256
        case byteSize = "byte_size"
        case schemaVersion = "schema_version"
        case schemaSHA256 = "schema_sha256"
    }
}

extension V3SelectedVADAudioFormat {
    enum CodingKeys: String, CodingKey {
        case sampleRateHz = "sample_rate_hz"
        case channels
        case sampleWidthBytes = "sample_width_bytes"
        case encoding
    }
}

extension V3SelectedVADReplaySemantics {
    enum CodingKeys: String, CodingKey {
        case trackOrder = "track_order"
        case resetStateBeforeEveryTrack = "reset_state_before_every_track"
        case emitEndOfStreamAfterEveryTrack = "emit_end_of_stream_after_every_track"
        case allowCrossTrackContinuation = "allow_cross_track_continuation"
        case interTrackGapSamples = "inter_track_gap_samples"
        case concatenateTracks = "concatenate_tracks"
    }
}
