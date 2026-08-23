import Foundation

enum V3SelectedVADReportValidator {
    static func validate(_ value: V3SelectedVADReport) throws {
        guard value.schemaVersion == 1,
            value.evidenceKind == "manifest-aware-selected-webrtc-vad-shadow-baseline",
            value.replayLane == "webrtcStable", value.decisionAuthority == "none",
            value.labelAuthority == "none", value.releaseStatus == "no-go",
            value.attempts.count == V3SelectedVADPolicy.trackCount,
            value.aggregates == V3SelectedVADAggregateBuilder.make(value.attempts),
            value.provenance.preflightIdentitySHA256
                == value.provenance.postflightIdentitySHA256
        else { throw V3SelectedVADError.provenanceMismatch("report envelope") }
        try validateAttempts(value.attempts)
        try validateAggregates(value.aggregates)
        try validateGate(value.releaseGate, aggregate: value.aggregates.genuineChurchSermons)
    }

    private static func validateAttempts(_ values: [V3SelectedVADAttempt]) throws {
        let identities = values.map { "\($0.logicalItemOrdinal):\($0.trackOrdinal)" }
        guard Set(identities).count == values.count,
            values == values.sorted(by: ordered),
            values.allSatisfy(validAttempt)
        else { throw V3SelectedVADError.provenanceMismatch("attempts") }
    }

    private static func validAttempt(_ value: V3SelectedVADAttempt) -> Bool {
        guard value.logicalItemOrdinal > 0, value.trackOrdinal > 0,
            V3SelectedVADManifestValidator.isDigest(value.sourceWAVSHA256),
            value.sourceWAVByteCount > 0, value.exactSampleFrames > 0,
            value.audioSeconds == Double(value.exactSampleFrames) / 16_000,
            value.resetBeforeTrack, value.endOfStreamAfterTrack,
            value.success == (value.failureCode == nil),
            value.success == (value.metrics != nil)
        else { return false }
        guard let metrics = value.metrics else { return true }
        return metrics.productionShadowParity
            && metrics.productionVoiceSignatureSHA256 == metrics.shadowVoiceSignatureSHA256
            && V3SelectedVADManifestValidator.isDigest(metrics.productionVoiceSignatureSHA256)
            && metrics.segmentCount == metrics.segmentDurationSamples.count
            && metrics.reasonCounts.values.reduce(0, +) == metrics.segmentCount
            && metrics.segmentDurationSamples.allSatisfy { $0 > 0 }
            && Set(metrics.candidateReachedCounts.keys).isSubset(of: ["250", "300", "400"])
    }

    private static func ordered(
        _ first: V3SelectedVADAttempt,
        _ second: V3SelectedVADAttempt
    ) -> Bool {
        (first.logicalItemOrdinal, first.trackOrdinal)
            < (second.logicalItemOrdinal, second.trackOrdinal)
    }
}
