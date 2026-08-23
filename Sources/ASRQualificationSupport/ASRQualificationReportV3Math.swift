enum ASRQualificationReportV3Math {
    static func timing(
        attempts: [ASRQualificationAttemptV3],
        decodedInputSeconds: Double,
        path: String
    ) throws -> ASRQualificationTimingSummaryV3 {
        let successful = attempts.filter { $0.status == .success }
        let allLatencies = attempts.map(\.elapsedSeconds)
        let successfulLatencies = successful.map(\.elapsedSeconds)
        let decodeSeconds = try finiteSum(allLatencies, path: "\(path).decodeSeconds")
        let realTimeFactor = decodeSeconds / decodedInputSeconds
        guard realTimeFactor.isFinite else {
            throw ASRQualificationReportV3Error.nonFiniteAggregate("\(path).realTimeFactor")
        }
        return ASRQualificationTimingSummaryV3(
            attemptCount: attempts.count,
            successCount: successful.count,
            failureCount: attempts.count - successful.count,
            successfulAttemptLatencyP50Seconds: percentile(0.50, in: successfulLatencies),
            successfulAttemptLatencyP95Seconds: percentile(0.95, in: successfulLatencies),
            allAttemptLatencyP50Seconds: percentile(0.50, in: allLatencies) ?? 0,
            allAttemptLatencyP95Seconds: percentile(0.95, in: allLatencies) ?? 0,
            withinThreeSecondsRate: withinThreeSecondsRate(
                successful: successful,
                attemptCount: attempts.count
            ),
            decodeSeconds: decodeSeconds,
            realTimeFactor: realTimeFactor
        )
    }

    static func unionSampleCount(
        _ segments: [ASRQualificationSegmentV2],
        path: String
    ) throws -> Int {
        guard let first = segments.first else { return 0 }
        var covered = 0
        var start = first.startSample
        var end = first.endSample
        for segment in segments.dropFirst() {
            if segment.startSample > end {
                covered = try checkedAdd(covered, end - start, path: path)
                start = segment.startSample
                end = segment.endSample
            } else {
                end = max(end, segment.endSample)
            }
        }
        return try checkedAdd(covered, end - start, path: path)
    }

    static func checkedSum(_ values: [Int], path: String) throws -> Int {
        try values.reduce(0) { try checkedAdd($0, $1, path: path) }
    }

    static func checkedAdd(_ left: Int, _ right: Int, path: String) throws -> Int {
        let (sum, overflow) = left.addingReportingOverflow(right)
        guard !overflow else {
            throw ASRQualificationReportV3Error.numericOverflow(path)
        }
        return sum
    }

    static func finiteSum(_ values: [Double], path: String) throws -> Double {
        let sum = values.reduce(0, +)
        guard sum.isFinite else {
            throw ASRQualificationReportV3Error.nonFiniteAggregate(path)
        }
        return sum
    }

    private static func percentile(_ percentile: Double, in values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = Int((Double(sorted.count - 1) * percentile).rounded(.up))
        return sorted[min(max(position, 0), sorted.count - 1)]
    }

    private static func withinThreeSecondsRate(
        successful: [ASRQualificationAttemptV3],
        attemptCount: Int
    ) -> Double {
        guard attemptCount > 0 else { return 0 }
        let withinThreshold = successful.count { $0.elapsedSeconds <= 3 }
        return Double(withinThreshold) / Double(attemptCount)
    }
}
