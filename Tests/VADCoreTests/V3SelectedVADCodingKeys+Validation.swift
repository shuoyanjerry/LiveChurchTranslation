import Foundation

extension V3SelectedVADValidationSidecar {
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case manifestSHA256 = "manifest_sha256"
        case sourceManifestSHA256 = "source_manifest_sha256"
        case logicalItemCount = "logical_item_count"
        case trackCount = "track_count"
        case genuineChurchSermonItemCount = "genuine_church_sermon_item_count"
        case scriptedOrNarrationProgramItemCount = "scripted_or_narration_program_item_count"
        case decodedDurationSeconds = "decoded_duration_seconds"
        case exactSampleFrames = "exact_sample_frames"
        case outputRootMode = "output_root_mode"
        case fileMode = "file_mode"
        case releaseSermonCountGateMet = "release_sermon_count_gate_met"
        case forbiddenExactTextFieldCount = "forbidden_exact_text_field_count"
        case sourceInputValidationErrorCount = "source_input_validation_error_count"
        case wavValidationErrorCount = "wav_validation_error_count"
        case durationValidationErrorCount = "duration_validation_error_count"
        case symlinkCount = "symlink_count"
        case replicaCount = "replica_count"
        case allThreeFullReplayReplicasByteIdentical =
            "all_three_full_replay_replicas_byte_identical"
    }
}
