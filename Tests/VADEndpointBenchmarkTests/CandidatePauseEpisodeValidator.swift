enum CandidatePauseEpisodeValidator {
    static func validate(_ events: [CandidatePauseEventRecord]) throws {
        let reachedEvents = events.filter { $0.reached != nil }
        let resolvedEvents = events.filter { $0.kind == "resolved" }
        guard let resolution = events.first?.resolution,
            let boundary = events.first?.finalizedBoundary,
            let resolved = resolvedEvents.first
        else { throw CandidatePauseBenchmarkError.invalidTrace("episode evidence is empty") }
        try validateCardinality(
            events: events,
            reachedEvents: reachedEvents,
            resolvedEvents: resolvedEvents,
            resolution: resolution,
            boundary: boundary
        )
        try validateReached(reachedEvents, resolution: resolution)
        try validateResolution(resolved, resolution: resolution, boundary: boundary)
    }

    private static func validateCardinality(
        events: [CandidatePauseEventRecord],
        reachedEvents: [CandidatePauseEventRecord],
        resolvedEvents: [CandidatePauseEventRecord],
        resolution: CandidatePauseResolutionRecord,
        boundary: CandidatePauseFinalizedBoundary
    ) throws {
        let thresholds = reachedEvents.compactMap { $0.reached?.thresholdMilliseconds }
        guard resolvedEvents.count == 1, !reachedEvents.isEmpty,
            thresholds == Array([250, 300, 400].prefix(thresholds.count)),
            events.allSatisfy({ $0.resolution == resolution }),
            events.allSatisfy({ $0.finalizedBoundary == boundary }),
            reachedEvents.allSatisfy({ $0.kind == "reached" }),
            resolvedEvents[0].reached == nil,
            resolvedEvents[0].ordinal > (reachedEvents.last?.ordinal ?? 0)
        else { throw CandidatePauseBenchmarkError.invalidTrace("episode cardinality failed") }
    }

    private static func validateReached(
        _ events: [CandidatePauseEventRecord],
        resolution: CandidatePauseResolutionRecord
    ) throws {
        let reached = events.compactMap(\.reached)
        guard let first = reached.first else {
            throw CandidatePauseBenchmarkError.invalidTrace("checkpoint evidence is empty")
        }
        let firstPauseOrigin = first.candidateEndSourceSample - first.thresholdSampleCount
        for (event, value) in zip(events, reached) {
            try validateCheckpoint(event, value: value)
        }
        try validateCheckpointDeltas(reached)
        let lastObservation = reached.map(\.observationEndSourceSample).max() ?? 0
        let lastCandidate = reached.map(\.candidateEndSourceSample).max() ?? 0
        guard firstPauseOrigin >= 0,
            resolution.observedAtSourceSample >= lastObservation,
            resolution.observedAtSourceSample >= lastCandidate
        else { throw CandidatePauseBenchmarkError.invalidTrace("resolution precedes checkpoint") }
    }

    private static func validateCheckpoint(
        _ event: CandidatePauseEventRecord,
        value: CandidatePauseReachedRecord
    ) throws {
        let expectedSamples = Int64(value.thresholdMilliseconds * 16)
        guard value.thresholdSampleCount == expectedSamples,
            value.observationStartSourceSample <= value.candidateEndSourceSample,
            value.observationEndSourceSample >= value.candidateEndSourceSample,
            value.overshootSampleCount
                == value.observationEndSourceSample - value.candidateEndSourceSample,
            event.observedAtSourceSample == value.observationEndSourceSample,
            candidatePauseSeconds(value.candidateEndSourceSample, match: value.candidateEndSeconds),
            candidatePauseSeconds(value.observationEndSourceSample, match: value.observationEndSeconds)
        else { throw CandidatePauseBenchmarkError.invalidTrace("checkpoint invariant failed") }
    }

    private static func validateCheckpointDeltas(
        _ reached: [CandidatePauseReachedRecord]
    ) throws {
        for pair in zip(reached, reached.dropFirst()) {
            let candidateDelta = pair.1.candidateEndSourceSample - pair.0.candidateEndSourceSample
            let thresholdDelta = pair.1.thresholdSampleCount - pair.0.thresholdSampleCount
            let excludedRawSpeechSamples = candidateDelta - thresholdDelta
            guard candidateDelta > 0, excludedRawSpeechSamples >= 0,
                excludedRawSpeechSamples.isMultiple(of: 320)
            else { throw CandidatePauseBenchmarkError.invalidTrace("checkpoint delta mismatch") }
        }
    }

    private static func validateResolution(
        _ event: CandidatePauseEventRecord,
        resolution: CandidatePauseResolutionRecord,
        boundary: CandidatePauseFinalizedBoundary
    ) throws {
        guard event.observedAtSourceSample == resolution.observedAtSourceSample,
            candidatePauseSeconds(
                resolution.observedAtSourceSample,
                match: resolution.observedAtSeconds
            )
        else { throw CandidatePauseBenchmarkError.invalidTrace("resolution clock mismatch") }
        switch resolution.kind {
        case "speechResumed":
            guard resolution.segmentEndReason == nil else {
                throw CandidatePauseBenchmarkError.invalidTrace("resumed resolution has end reason")
            }
        case "segmentEnded":
            guard resolution.segmentEndReason == boundary.reason else {
                throw CandidatePauseBenchmarkError.invalidTrace("segment-end resolution mismatch")
            }
        default:
            throw CandidatePauseBenchmarkError.invalidTrace("unknown resolution kind")
        }
    }
}
