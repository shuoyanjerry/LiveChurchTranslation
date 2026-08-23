import Foundation

enum V3SelectedVADManifestValidator {
    static func validate(
        _ manifest: V3SelectedVADManifest,
        validation: V3SelectedVADValidationSidecar
    ) throws {
        try validateHeader(manifest)
        try validateSummary(manifest.summary)
        try validateScenes(manifest.sceneClassAggregate)
        try validateItems(manifest.items)
        try validateSidecar(validation)
    }

    private static func validateHeader(_ value: V3SelectedVADManifest) throws {
        guard value.schemaVersion == 1,
            value.manifestKind == "boundary-preserving-local-vad-replay-pcm",
            value.visibility == "gitignored-private-local-qa-only",
            !value.containsTranscriptText, !value.containsTitleSpeakerURLOrSceneText,
            value.sourceManifest.sha256 == V3SelectedVADPolicy.sourceManifestSHA256,
            value.sourceManifest.schemaSHA256 == V3SelectedVADPolicy.sourceSchemaSHA256,
            value.sourceManifest.schemaVersion == 1,
            value.builder.sha256 == V3SelectedVADPolicy.builderSHA256,
            value.conversionPolicySHA256 == V3SelectedVADPolicy.conversionPolicySHA256,
            value.audioFormat.sampleRateHz == 16_000, value.audioFormat.channels == 1,
            value.audioFormat.sampleWidthBytes == 2,
            value.audioFormat.encoding == "signed-16-bit-little-endian-pcm-wave"
        else { throw V3SelectedVADError.invalidManifest("header") }
        let replay = value.replaySemantics
        guard replay.trackOrder == "ascending-ordinal-within-logical-item",
            replay.resetStateBeforeEveryTrack, replay.emitEndOfStreamAfterEveryTrack,
            !replay.allowCrossTrackContinuation, replay.interTrackGapSamples == 0,
            !replay.concatenateTracks
        else { throw V3SelectedVADError.invalidManifest("replay semantics") }
    }

    private static func validateSummary(_ value: V3SelectedVADManifestSummary) throws {
        guard value.logicalItemCount == V3SelectedVADPolicy.logicalItemCount,
            value.genuineChurchSermonItemCount == V3SelectedVADPolicy.genuineItemCount,
            value.scriptedOrNarrationProgramItemCount == V3SelectedVADPolicy.scriptedItemCount,
            value.trackCount == V3SelectedVADPolicy.trackCount,
            value.exactDecodedSampleFrames == V3SelectedVADPolicy.sampleFrames,
            close(value.exactDecodedDurationSeconds, V3SelectedVADPolicy.audioSeconds),
            !value.releaseSermonCountGateMet
        else { throw V3SelectedVADError.invalidManifest("summary") }
    }

    private static func validateScenes(_ values: [V3SelectedVADSceneAggregate]) throws {
        guard values.count == 2 else { throw V3SelectedVADError.invalidManifest("scenes") }
        let keyed = Dictionary(uniqueKeysWithValues: values.map { ($0.itemClass, $0) })
        try validateScene(
            keyed[.genuineChurchSermon],
            items: V3SelectedVADPolicy.genuineItemCount,
            tracks: V3SelectedVADPolicy.genuineTrackCount,
            samples: V3SelectedVADPolicy.genuineSampleFrames
        )
        try validateScene(
            keyed[.scriptedOrNarrationProgram],
            items: V3SelectedVADPolicy.scriptedItemCount,
            tracks: V3SelectedVADPolicy.scriptedTrackCount,
            samples: V3SelectedVADPolicy.scriptedSampleFrames
        )
    }

    private static func validateScene(
        _ value: V3SelectedVADSceneAggregate?,
        items: Int,
        tracks: Int,
        samples: Int64
    ) throws {
        guard let value, value.logicalItemCount == items, value.trackCount == tracks,
            value.exactSampleFrames == samples,
            close(value.exactDurationSeconds, Double(samples) / 16_000)
        else { throw V3SelectedVADError.invalidManifest("scene aggregate") }
    }

    static func close(_ first: Double, _ second: Double) -> Bool {
        abs(first - second) <= 0.000_000_001
    }
}
