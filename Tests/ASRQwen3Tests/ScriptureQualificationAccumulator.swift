import ScriptureQualificationSupport

struct ScriptureQualificationObservation: Sendable {
    let partition: ScriptureQualificationPartition
    let lane: ScriptureQualificationLane
    let metric: ScriptureQualificationMetric?
    let audioSeconds: Double
    let runtimeSeconds: Double
    let failure: ScriptureQualificationFailureCode?
    let diagnosticCode: String?

    static func success(
        partition: ScriptureQualificationPartition,
        lane: ScriptureQualificationLane,
        metric: ScriptureQualificationMetric,
        audioSeconds: Double = 0,
        runtimeSeconds: Double
    ) -> Self {
        Self(
            partition: partition,
            lane: lane,
            metric: metric,
            audioSeconds: audioSeconds,
            runtimeSeconds: runtimeSeconds,
            failure: nil,
            diagnosticCode: nil
        )
    }

    static func failure(
        partition: ScriptureQualificationPartition,
        lane: ScriptureQualificationLane,
        code: ScriptureQualificationFailureCode,
        diagnosticCode: String? = nil,
        audioSeconds: Double = 0,
        runtimeSeconds: Double = 0
    ) -> Self {
        Self(
            partition: partition,
            lane: lane,
            metric: nil,
            audioSeconds: audioSeconds,
            runtimeSeconds: runtimeSeconds,
            failure: code,
            diagnosticCode: diagnosticCode
        )
    }
}

struct ScriptureQualificationAccumulator {
    private var values: [Key: State] = [:]

    mutating func append(contentsOf observations: [ScriptureQualificationObservation]) {
        observations.forEach { append($0) }
    }

    func aggregates(
        partitions: [ScriptureQualificationPartition] = ScriptureQualificationPartition.allCases
    ) -> [ScriptureQualificationAggregate] {
        partitions.flatMap { partition in
            ScriptureQualificationLane.allCases.map { lane in
                aggregate(partition: partition, lane: lane)
            }
        }
    }

    private mutating func append(_ observation: ScriptureQualificationObservation) {
        let key = Key(partition: observation.partition.rawValue, lane: observation.lane)
        var state = values[key] ?? State()
        state.attemptCount += 1
        state.audioSeconds += observation.audioSeconds
        state.runtimeSeconds += observation.runtimeSeconds
        if let metric = observation.metric {
            state.successCount += 1
            state.editCount += metric.editCount
            state.referenceUnitCount += metric.referenceUnitCount
            state.referencePunctuationCount += metric.referencePunctuationCount
            state.hypothesisPunctuationCount += metric.hypothesisPunctuationCount
            state.punctuationEditCount += metric.punctuationEditCount
        } else if let failure = observation.failure {
            let code = observation.diagnosticCode ?? failure.rawValue
            state.failureCounts[code, default: 0] += 1
        }
        values[key] = state
    }

    private func aggregate(
        partition: ScriptureQualificationPartition,
        lane: ScriptureQualificationLane
    ) -> ScriptureQualificationAggregate {
        let state = values[Key(partition: partition.rawValue, lane: lane)] ?? State()
        return ScriptureQualificationAggregate(
            partition: partition,
            lane: lane,
            metricUnit: lane.metricUnit,
            attemptCount: state.attemptCount,
            successCount: state.successCount,
            failureCount: state.attemptCount - state.successCount,
            editCount: state.editCount,
            referenceUnitCount: state.referenceUnitCount,
            errorRate: rate(state.editCount, denominator: state.referenceUnitCount),
            referencePunctuationCount: state.referencePunctuationCount,
            hypothesisPunctuationCount: state.hypothesisPunctuationCount,
            punctuationEditCount: state.punctuationEditCount,
            punctuationErrorRate: rate(
                state.punctuationEditCount,
                denominator: state.referencePunctuationCount
            ),
            audioSeconds: state.audioSeconds,
            runtimeSeconds: state.runtimeSeconds,
            failureCounts: state.failureCounts
        )
    }

    private func rate(_ numerator: Int, denominator: Int) -> Double {
        denominator == 0 ? (numerator == 0 ? 0 : 1) : Double(numerator) / Double(denominator)
    }
}

private struct Key: Hashable {
    let partition: String
    let lane: ScriptureQualificationLane
}

private struct State {
    var attemptCount = 0
    var successCount = 0
    var editCount = 0
    var referenceUnitCount = 0
    var referencePunctuationCount = 0
    var hypothesisPunctuationCount = 0
    var punctuationEditCount = 0
    var audioSeconds = 0.0
    var runtimeSeconds = 0.0
    var failureCounts: [String: Int] = [:]
}
