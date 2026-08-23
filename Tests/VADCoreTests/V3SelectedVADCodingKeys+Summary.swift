import Foundation

extension V3SelectedVADManifestSummary {
    enum CodingKeys: String, CodingKey {
        case logicalItemCount = "logical_item_count"
        case genuineChurchSermonItemCount = "genuine_church_sermon_item_count"
        case scriptedOrNarrationProgramItemCount = "scripted_or_narration_program_item_count"
        case trackCount = "track_count"
        case exactDecodedSampleFrames = "exact_decoded_sample_frames"
        case exactDecodedDurationSeconds = "exact_decoded_duration_seconds"
        case releaseSermonCountGateMet = "release_sermon_count_gate_met"
    }
}

extension V3SelectedVADSceneAggregate {
    enum CodingKeys: String, CodingKey {
        case itemClass = "item_class"
        case logicalItemCount = "logical_item_count"
        case trackCount = "track_count"
        case exactSampleFrames = "exact_sample_frames"
        case exactDurationSeconds = "exact_duration_seconds"
    }
}

extension V3SelectedVADManifestItem {
    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case itemClass = "item_class"
        case trackCount = "track_count"
        case concatenated
        case tracks
    }
}

extension V3SelectedVADManifestTrack {
    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case ordinal
        case relativeWAVPath = "relative_wav_path"
        case convertedWAVSHA256 = "converted_wav_sha256"
        case convertedWAVByteSize = "converted_wav_byte_size"
        case exactSampleFrames = "exact_sample_frames"
        case exactDurationSeconds = "exact_duration_seconds"
        case pcmDataByteSize = "pcm_data_byte_size"
        case resetStateBeforeTrack = "reset_state_before_track"
        case emitEndOfStreamAfterTrack = "emit_end_of_stream_after_track"
        case allowContinuationFromPreviousTrack = "allow_continuation_from_previous_track"
    }
}
