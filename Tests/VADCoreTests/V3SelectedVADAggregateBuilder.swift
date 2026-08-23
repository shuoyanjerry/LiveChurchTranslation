import Foundation

enum V3SelectedVADAggregateBuilder {
    static func make(_ attempts: [V3SelectedVADAttempt]) -> V3SelectedVADAggregates {
        V3SelectedVADAggregates(
            overall: aggregate(attempts),
            genuineChurchSermons: aggregate(
                attempts.filter { $0.sceneClass == .genuineChurchSermon }
            ),
            scriptedOrNarrationPrograms: aggregate(
                attempts.filter { $0.sceneClass == .scriptedOrNarrationProgram }
            )
        )
    }

    static func aggregate(_ attempts: [V3SelectedVADAttempt]) -> V3SelectedVADMetricAggregate {
        let metrics = attempts.compactMap(\.metrics)
        let durations = metrics.flatMap(\.segmentDurationSamples).sorted()
        let reasons = merged(metrics.map(\.reasonCounts))
        return V3SelectedVADMetricAggregate(
            logicalItemCount: Set(attempts.map(\.logicalItemOrdinal)).count,
            trackAttemptCount: attempts.count,
            successCount: attempts.count { $0.success },
            failureCount: attempts.count { !$0.success },
            expectedSampleFrames: attempts.reduce(0) { $0 + $1.exactSampleFrames },
            expectedAudioSeconds: attempts.reduce(0) { $0 + $1.audioSeconds },
            successfulSampleFrames: attempts.filter(\.success).reduce(0) {
                $0 + $1.exactSampleFrames
            },
            segmentCount: metrics.reduce(0) { $0 + $1.segmentCount },
            underTwoSecondsCount: metrics.reduce(0) { $0 + $1.underTwoSecondsCount },
            forcedHardCutProxyCount: reasons["maximumDuration", default: 0],
            reasonCounts: reasons,
            failureCodeCounts: failureCounts(attempts),
            segmentDurationSamplesP50: nearestRank(0.50, durations),
            segmentDurationSamplesP95: nearestRank(0.95, durations),
            segmentDurationSamplesP99: nearestRank(0.99, durations),
            candidateReachedCounts: merged(metrics.map(\.candidateReachedCounts)),
            candidateResolutionCounts: merged(metrics.map(\.candidateResolutionCounts)),
            parityPassCount: metrics.count { $0.productionShadowParity }
        )
    }

    private static func merged(_ dictionaries: [[String: Int]]) -> [String: Int] {
        dictionaries.reduce(into: [:]) { result, value in
            for (key, count) in value { result[key, default: 0] += count }
        }
    }

    private static func failureCounts(_ attempts: [V3SelectedVADAttempt]) -> [String: Int] {
        attempts.compactMap(\.failureCode).reduce(into: [:]) {
            $0[$1.rawValue, default: 0] += 1
        }
    }

    private static func nearestRank(_ percentile: Double, _ sorted: [Int]) -> Int? {
        guard !sorted.isEmpty else { return nil }
        let rank = max(1, Int((percentile * Double(sorted.count)).rounded(.up)))
        return sorted[min(rank - 1, sorted.count - 1)]
    }
}
