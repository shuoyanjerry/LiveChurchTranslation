enum CandidatePauseBenchmarkConsole {
    static func printSummary(
        _ value: CandidatePauseAggregate,
        artifactSHA256: String,
        mode: UInt16
    ) {
        print(
            "CANDIDATE_PAUSE_SHADOW_TOTAL=files:\(value.fileCount),"
                + "events:\(value.eventCount),reached:\(value.reachedCount),"
                + "resolved:\(value.resolvedCount),episodes:\(value.episodeCount),"
                + "eofPaddingReconciled:\(value.sourceEOFPaddingSamples),"
                + "eofLagReconciled:\(value.sourceEOFLagCount),"
                + "resolution:\(formatted(value.resolutionCounts)),"
                + "final:\(formatted(value.finalEndReasonCounts))"
        )
        for threshold in value.thresholds {
            print(
                "CANDIDATE_PAUSE_SHADOW_\(threshold.thresholdMilliseconds)MS="
                    + "reached:\(threshold.reachedCount),"
                    + "resolution:\(formatted(threshold.resolutionCounts)),"
                    + "final:\(formatted(threshold.finalEndReasonCounts))"
            )
        }
        print("CANDIDATE_PAUSE_SHADOW_ARTIFACT_SHA256=\(artifactSHA256)")
        print("CANDIDATE_PAUSE_SHADOW_ARTIFACT_MODE=\(String(mode, radix: 8))")
        print("CANDIDATE_PAUSE_SHADOW_RUNTIME_CAVEAT=descriptive-only-no-SLA")
    }

    private static func formatted(_ values: [String: Int]) -> String {
        values.keys.sorted().map { "\($0):\(values[$0, default: 0])" }.joined(separator: "|")
    }
}
