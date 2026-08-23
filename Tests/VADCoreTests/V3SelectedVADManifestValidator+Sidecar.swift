import Foundation

extension V3SelectedVADManifestValidator {
    static func validateSidecar(_ value: V3SelectedVADValidationSidecar) throws {
        guard value.schemaVersion == 1,
            value.manifestSHA256 == V3SelectedVADPolicy.manifestSHA256,
            value.sourceManifestSHA256 == V3SelectedVADPolicy.sourceManifestSHA256,
            value.logicalItemCount == V3SelectedVADPolicy.logicalItemCount,
            value.trackCount == V3SelectedVADPolicy.trackCount,
            value.genuineChurchSermonItemCount == V3SelectedVADPolicy.genuineItemCount,
            value.scriptedOrNarrationProgramItemCount == V3SelectedVADPolicy.scriptedItemCount,
            close(value.decodedDurationSeconds, V3SelectedVADPolicy.audioSeconds),
            value.exactSampleFrames == V3SelectedVADPolicy.sampleFrames,
            value.outputRootMode == "0700", value.fileMode == "0600",
            !value.releaseSermonCountGateMet,
            value.forbiddenExactTextFieldCount == 0,
            value.sourceInputValidationErrorCount == 0,
            value.wavValidationErrorCount == 0, value.durationValidationErrorCount == 0,
            value.symlinkCount == 0, value.replicaCount == 3,
            value.allThreeFullReplayReplicasByteIdentical
        else { throw V3SelectedVADError.invalidManifest("validation sidecar") }
    }
}
