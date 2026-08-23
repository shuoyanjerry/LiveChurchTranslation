enum CandidatePauseEventValidator {
    static func validate(
        _ events: [CandidatePauseEventRecord],
        boundaries: [CandidatePauseFinalizedBoundary]
    ) throws {
        let boundaryMap = Dictionary(uniqueKeysWithValues: boundaries.map { ($0.sequenceNumber, $0) })
        try validateMonotonicity(events)
        for event in events {
            guard boundaryMap[event.sequenceNumber] == event.finalizedBoundary else {
                throw CandidatePauseBenchmarkError.invalidTrace("event boundary join failed")
            }
        }
        let groups = Dictionary(grouping: events) {
            CandidatePauseEventKey(sequence: $0.sequenceNumber, episode: $0.episodeNumber)
        }
        for values in groups.values {
            try CandidatePauseEpisodeValidator.validate(values)
        }
    }

    private static func validateMonotonicity(
        _ events: [CandidatePauseEventRecord]
    ) throws {
        var previous: CandidatePauseEventRecord?
        for event in events {
            if let previous {
                guard event.emittedAfterSourceSample >= previous.emittedAfterSourceSample,
                    event.observedAtSourceSample >= previous.observedAtSourceSample,
                    CandidatePauseEventKey(event) >= CandidatePauseEventKey(previous)
                else {
                    throw CandidatePauseBenchmarkError.invalidTrace("event order is not monotonic")
                }
            }
            guard event.emittedAfterSourceSample >= event.observedAtSourceSample,
                candidatePauseSeconds(event.observedAtSourceSample, match: event.observedAtSeconds)
            else { throw CandidatePauseBenchmarkError.invalidTrace("event clock mismatch") }
            previous = event
        }
    }
}

struct CandidatePauseEventKey: Hashable, Comparable {
    let sequence: UInt64
    let episode: UInt64

    init(sequence: UInt64, episode: UInt64) {
        self.sequence = sequence
        self.episode = episode
    }

    init(_ event: CandidatePauseEventRecord) {
        self.init(sequence: event.sequenceNumber, episode: event.episodeNumber)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.sequence < rhs.sequence
            || (lhs.sequence == rhs.sequence && lhs.episode < rhs.episode)
    }
}

func candidatePauseSeconds(_ samples: Int64, match value: Double) -> Bool {
    abs(Double(samples) / 16_000 - value) <= 0.000_000_001
}
