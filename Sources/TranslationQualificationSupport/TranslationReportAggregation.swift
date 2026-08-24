import Foundation

extension TranslationQualificationReportBuilder {
    static func aggregate(
        _ attempts: [TranslationQualificationAttempt]
    ) -> TranslationQualificationAggregate {
        let statuses = attempts.flatMap { attempt in
            attempt.preservationChecks.map(\.status)
                + attempt.glossaryTerms.map(\.status)
                + attempt.pronounResults.flatMap { [$0.guidanceStatus, $0.englishPolicyStatus] }
        }
        return TranslationQualificationAggregate(
            attemptCount: attempts.count,
            successCount: attempts.filter { $0.status == .success }.count,
            failureCount: attempts.filter { $0.status == .failure }.count,
            strictRetryCount: attempts.filter(\.strictRetryUsed).count,
            safetyFallbackCount: attempts.filter { $0.safetyFallbackUsed == true }.count,
            latency: latency(attempts.map(\.latencySeconds)),
            checkPassCount: statuses.filter { $0 == .pass }.count,
            checkFailCount: statuses.filter { $0 == .fail }.count,
            humanReviewRequiredCount: statuses.filter { $0 == .humanReviewRequired }.count
        )
    }

    private static func latency(_ values: [Double]) -> TranslationQualificationLatency {
        let sorted = values.sorted()
        return TranslationQualificationLatency(
            minimumSeconds: sorted.first ?? 0,
            medianSeconds: percentile(0.5, sorted: sorted),
            p95Seconds: percentile(0.95, sorted: sorted),
            maximumSeconds: sorted.last ?? 0
        )
    }

    private static func percentile(_ value: Double, sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let position = Int(ceil(value * Double(sorted.count))) - 1
        return sorted[max(0, min(sorted.count - 1, position))]
    }
}
