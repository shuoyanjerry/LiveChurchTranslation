import VADAPI

struct CandidatePauseRecorder {
    private var captured: [CandidatePauseCapturedEvent] = []

    mutating func append(
        _ events: [CandidatePauseTraceEvent],
        emittedAfterSourceSample: Int64
    ) {
        for event in events {
            captured.append(
                CandidatePauseCapturedEvent(
                    ordinal: captured.count + 1,
                    emittedAfterSourceSample: emittedAfterSourceSample,
                    event: event
                )
            )
        }
    }

    func finalized(
        boundaries: [VADBoundaryRecord]
    ) throws -> [CandidatePauseEventRecord] {
        let resolutions = try resolutionMap()
        let boundaryMap = try finalizedBoundaryMap(boundaries)
        try validateLifecycle(resolutions: resolutions)
        return try captured.map {
            try makeRecord($0, resolutions: resolutions, boundaries: boundaryMap)
        }
    }

    private func resolutionMap() throws -> [CandidatePauseEpisodeKey: CandidatePauseResolved] {
        var values: [CandidatePauseEpisodeKey: CandidatePauseResolved] = [:]
        for value in captured {
            guard case .resolved(let resolved) = value.event else { continue }
            let key = CandidatePauseEpisodeKey(resolved.episode)
            guard values.updateValue(resolved, forKey: key) == nil else {
                throw CandidatePauseBenchmarkError.invalidTrace("duplicate episode resolution")
            }
        }
        return values
    }

    private func finalizedBoundaryMap(
        _ boundaries: [VADBoundaryRecord]
    ) throws -> [UInt64: CandidatePauseFinalizedBoundary] {
        var values: [UInt64: CandidatePauseFinalizedBoundary] = [:]
        for boundary in boundaries {
            let value = CandidatePauseFinalizedBoundary(boundary)
            guard values.updateValue(value, forKey: boundary.sequenceNumber) == nil else {
                throw CandidatePauseBenchmarkError.invalidTrace("duplicate finalized sequence")
            }
        }
        return values
    }

    private func validateLifecycle(
        resolutions: [CandidatePauseEpisodeKey: CandidatePauseResolved]
    ) throws {
        var reached: [CandidatePauseEpisodeKey: [Int]] = [:]
        for value in captured {
            guard case .reached(let evidence) = value.event else { continue }
            reached[CandidatePauseEpisodeKey(evidence.episode), default: []].append(
                evidence.checkpoint.threshold.rawValue
            )
        }
        guard Set(reached.keys) == Set(resolutions.keys) else {
            throw CandidatePauseBenchmarkError.invalidTrace("unresolved episode")
        }
        for thresholds in reached.values {
            guard thresholds == Array(Set(thresholds)).sorted() else {
                throw CandidatePauseBenchmarkError.invalidTrace("checkpoint order mismatch")
            }
        }
    }

    private func makeRecord(
        _ captured: CandidatePauseCapturedEvent,
        resolutions: [CandidatePauseEpisodeKey: CandidatePauseResolved],
        boundaries: [UInt64: CandidatePauseFinalizedBoundary]
    ) throws -> CandidatePauseEventRecord {
        let episode = captured.event.episode
        let key = CandidatePauseEpisodeKey(episode)
        guard let resolved = resolutions[key],
            let boundary = boundaries[episode.sequenceNumber]
        else { throw CandidatePauseBenchmarkError.invalidTrace("trace join failed") }
        let observed = captured.event.observedAt
        return CandidatePauseEventRecord(
            ordinal: captured.ordinal,
            kind: captured.event.kind,
            sequenceNumber: episode.sequenceNumber,
            episodeNumber: episode.episodeNumber,
            observedAtSourceSample: observed.sourceSample,
            observedAtSeconds: observed.timestamp.secondsValue,
            emittedAfterSourceSample: captured.emittedAfterSourceSample,
            reached: captured.event.reachedRecord,
            resolution: CandidatePauseResolutionRecord(resolved),
            finalizedBoundary: boundary
        )
    }
}

private struct CandidatePauseCapturedEvent {
    let ordinal: Int
    let emittedAfterSourceSample: Int64
    let event: CandidatePauseTraceEvent
}

private struct CandidatePauseEpisodeKey: Hashable {
    let sequenceNumber: UInt64
    let episodeNumber: UInt64

    init(_ episode: CandidatePauseEpisode) {
        sequenceNumber = episode.sequenceNumber
        episodeNumber = episode.episodeNumber
    }
}

extension CandidatePauseTraceEvent {
    fileprivate var episode: CandidatePauseEpisode {
        switch self {
        case .reached(let value): value.episode
        case .resolved(let value): value.episode
        }
    }

    fileprivate var observedAt: CandidatePauseTraceInstant {
        switch self {
        case .reached(let value): value.currentWindow.end
        case .resolved(let value): value.observedAt
        }
    }

    fileprivate var kind: String {
        switch self {
        case .reached: "reached"
        case .resolved: "resolved"
        }
    }

    fileprivate var reachedRecord: CandidatePauseReachedRecord? {
        guard case .reached(let value) = self else { return nil }
        return CandidatePauseReachedRecord(value)
    }
}
