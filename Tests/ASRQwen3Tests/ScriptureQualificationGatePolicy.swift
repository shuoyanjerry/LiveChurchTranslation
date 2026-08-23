import ScriptureQualificationSupport

enum ScriptureQualificationGatePolicy {
    static let revision = "scripture-production-sealed-v1-frozen-2026-08-23"
    static let minimumSealedPairs = 6

    static func evaluate(
        _ aggregates: [ScriptureQualificationAggregate]
    ) -> [ScriptureQualificationLaneGate] {
        let sealed = aggregates.filter { $0.partition == .sealedBlindQualification }
        return ScriptureQualificationLane.allCases.compactMap { lane in
            guard let aggregate = sealed.first(where: { $0.lane == lane }),
                let threshold = thresholds[lane]
            else { return nil }
            return gate(aggregate, threshold: threshold)
        }
    }

    static func qualifies(_ gates: [ScriptureQualificationLaneGate]) -> Bool {
        gates.count == ScriptureQualificationLane.allCases.count
            && gates.allSatisfy(\.passed)
    }

    private static func gate(
        _ aggregate: ScriptureQualificationAggregate,
        threshold: Threshold
    ) -> ScriptureQualificationLaneGate {
        let averageRuntime = average(
            aggregate.runtimeSeconds,
            count: aggregate.attemptCount
        )
        let realTimeFactor =
            aggregate.audioSeconds > 0
            ? aggregate.runtimeSeconds / aggregate.audioSeconds : nil
        let passed =
            aggregate.attemptCount >= minimumSealedPairs
            && aggregate.failureCount == 0
            && aggregate.errorRate <= threshold.maximumErrorRate
            && averageRuntime <= threshold.maximumAverageRuntimeSeconds
            && below(realTimeFactor, maximum: threshold.maximumRealTimeFactor)
        return ScriptureQualificationLaneGate(
            partition: aggregate.partition,
            lane: aggregate.lane,
            minimumAttempts: minimumSealedPairs,
            requiresZeroFailures: true,
            maximumErrorRate: threshold.maximumErrorRate,
            maximumAverageRuntimeSeconds: threshold.maximumAverageRuntimeSeconds,
            maximumRealTimeFactor: threshold.maximumRealTimeFactor,
            observedAttempts: aggregate.attemptCount,
            observedFailures: aggregate.failureCount,
            observedErrorRate: aggregate.errorRate,
            observedAverageRuntimeSeconds: averageRuntime,
            observedRealTimeFactor: realTimeFactor,
            passed: passed
        )
    }

    private static func average(_ total: Double, count: Int) -> Double {
        count > 0 ? total / Double(count) : 0
    }

    private static func below(_ value: Double?, maximum: Double?) -> Bool {
        guard let maximum else { return true }
        guard let value else { return false }
        return value <= maximum
    }

    private static let thresholds: [ScriptureQualificationLane: Threshold] = [
        .englishASR: .init(error: 0.12, averageRuntime: 30, realTimeFactor: 1.25),
        .simplifiedChineseASR: .init(error: 0.08, averageRuntime: 30, realTimeFactor: 1.25),
        .englishToSimplifiedChineseCleanText: .init(
            error: 0.70,
            averageRuntime: 30
        ),
        .simplifiedChineseToEnglishCleanText: .init(
            error: 0.75,
            averageRuntime: 30
        ),
        .englishASRToSimplifiedChinese: .init(
            error: 0.80,
            averageRuntime: 45,
            realTimeFactor: 4
        ),
        .simplifiedChineseASRToEnglish: .init(
            error: 0.85,
            averageRuntime: 45,
            realTimeFactor: 4
        ),
    ]
}

private struct Threshold {
    let maximumErrorRate: Double
    let maximumAverageRuntimeSeconds: Double
    let maximumRealTimeFactor: Double?

    init(error: Double, averageRuntime: Double, realTimeFactor: Double? = nil) {
        maximumErrorRate = error
        maximumAverageRuntimeSeconds = averageRuntime
        maximumRealTimeFactor = realTimeFactor
    }
}
