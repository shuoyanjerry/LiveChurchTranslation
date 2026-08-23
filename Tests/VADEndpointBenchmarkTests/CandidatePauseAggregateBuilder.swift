enum CandidatePauseAggregateBuilder {
    static func make(files: [CandidatePauseFileReport]) -> CandidatePauseAggregate {
        let events = files.flatMap(\.events)
        let episodes = files.flatMap { uniqueEpisodes($0.events) }
        return CandidatePauseAggregate(
            fileCount: files.count,
            audioSeconds: files.reduce(0) { $0 + $1.audioSeconds },
            finalizedBoundaryCount: files.reduce(0) { $0 + $1.finalizedBoundaries.count },
            sourceEOFPaddingSamples: files.reduce(0) {
                $0 + $1.sourceEOFPaddingSamples
            },
            sourceEOFLagCount: files.reduce(0) {
                $0 + $1.sourceEOFLagCount
            },
            eventCount: events.count,
            reachedCount: events.count { $0.reached != nil },
            resolvedCount: events.count { $0.kind == "resolved" },
            episodeCount: episodes.count,
            resolutionCounts: counts(episodes.map(resolutionName)),
            finalEndReasonCounts: counts(episodes.map { $0.finalizedBoundary.reason }),
            thresholds: [250, 300, 400].map { threshold($0, events: events) }
        )
    }

    private static func threshold(
        _ milliseconds: Int,
        events: [CandidatePauseEventRecord]
    ) -> CandidatePauseThresholdAggregate {
        let matches = events.filter { $0.reached?.thresholdMilliseconds == milliseconds }
        return CandidatePauseThresholdAggregate(
            thresholdMilliseconds: milliseconds,
            reachedCount: matches.count,
            resolutionCounts: counts(matches.map(resolutionName)),
            finalEndReasonCounts: counts(matches.map { $0.finalizedBoundary.reason })
        )
    }

    private static func uniqueEpisodes(
        _ events: [CandidatePauseEventRecord]
    ) -> [CandidatePauseEventRecord] {
        var seen: Set<AggregateEpisodeKey> = []
        return events.filter {
            seen.insert(
                AggregateEpisodeKey(
                    sequenceNumber: $0.sequenceNumber,
                    episodeNumber: $0.episodeNumber
                )
            ).inserted
        }
    }

    private static func resolutionName(_ event: CandidatePauseEventRecord) -> String {
        guard let reason = event.resolution.segmentEndReason else {
            return event.resolution.kind
        }
        return "\(event.resolution.kind):\(reason)"
    }

    private static func counts(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }
}

private struct AggregateEpisodeKey: Hashable {
    let sequenceNumber: UInt64
    let episodeNumber: UInt64
}
