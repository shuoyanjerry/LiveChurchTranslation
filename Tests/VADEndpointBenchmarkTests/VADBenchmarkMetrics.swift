struct VADMetrics {
    let audioSeconds: Double
    let processingSeconds: Double
    let boundaries: [VADBoundaryRecord]

    var rtf: Double { audioSeconds > 0 ? processingSeconds / audioSeconds : 0 }
    var segmentCount: Int { boundaries.count }
    var underTwoSecondsCount: Int { boundaries.count { $0.durationSeconds < 2 } }
    var forcedHardCutProxyCount: Int { reasonCounts["maximumDuration", default: 0] }
    var underTwoSecondsRate: Double { rate(underTwoSecondsCount) }
    var forcedHardCutProxyRate: Double { rate(forcedHardCutProxyCount) }
    var durationPercentiles: VADPercentiles {
        percentiles(boundaries.map(\.durationSeconds))
    }
    var emissionLagPercentiles: VADPercentiles {
        percentiles(boundaries.compactMap(\.emissionLagAfterRetainedAudioSeconds))
    }
    var reasonCounts: [String: Int] {
        boundaries.reduce(into: [:]) { $0[$1.reason, default: 0] += 1 }
    }

    private func rate(_ count: Int) -> Double {
        segmentCount > 0 ? Double(count) / Double(segmentCount) : 0
    }

    private func percentiles(_ values: [Double]) -> VADPercentiles {
        let sorted = values.sorted()
        return VADPercentiles(
            p50: nearestRank(0.50, in: sorted),
            p95: nearestRank(0.95, in: sorted),
            p99: nearestRank(0.99, in: sorted)
        )
    }

    private func nearestRank(_ percentile: Double, in sorted: [Double]) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let rank = max(1, Int((percentile * Double(sorted.count)).rounded(.up)))
        return sorted[min(rank - 1, sorted.count - 1)]
    }
}
