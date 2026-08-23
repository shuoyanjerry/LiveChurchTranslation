import Foundation

extension V3SelectedVADReportValidator {
    static func validateAggregates(_ value: V3SelectedVADAggregates) throws {
        guard value.overall.logicalItemCount == V3SelectedVADPolicy.logicalItemCount,
            value.overall.trackAttemptCount == V3SelectedVADPolicy.trackCount,
            value.overall.expectedSampleFrames == V3SelectedVADPolicy.sampleFrames,
            value.genuineChurchSermons.logicalItemCount == V3SelectedVADPolicy.genuineItemCount,
            value.genuineChurchSermons.trackAttemptCount == V3SelectedVADPolicy.genuineTrackCount,
            value.genuineChurchSermons.expectedSampleFrames
                == V3SelectedVADPolicy.genuineSampleFrames,
            value.scriptedOrNarrationPrograms.logicalItemCount
                == V3SelectedVADPolicy.scriptedItemCount,
            value.scriptedOrNarrationPrograms.trackAttemptCount
                == V3SelectedVADPolicy.scriptedTrackCount,
            value.scriptedOrNarrationPrograms.expectedSampleFrames
                == V3SelectedVADPolicy.scriptedSampleFrames
        else { throw V3SelectedVADError.provenanceMismatch("aggregates") }
    }

    static func validateGate(
        _ value: V3SelectedVADReleaseGate,
        aggregate: V3SelectedVADMetricAggregate
    ) throws {
        guard value.humanLabelCount == 0, !value.accuracyEligible,
            value.requiredGenuineSermonCount == 12,
            value.observedGenuineSermonCount == aggregate.logicalItemCount,
            !value.genuineSermonCountGateMet,
            value.requiredGenuineAudioSeconds == 28_800,
            value.observedGenuineAudioSeconds == aggregate.expectedAudioSeconds,
            !value.genuineAudioDurationGateMet, !value.releaseEligible
        else { throw V3SelectedVADError.provenanceMismatch("release gate") }
    }
}
