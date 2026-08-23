import ScriptureQualificationSupport
import Testing

@Suite struct ScriptureQualificationGatePolicyTests {
    @Test("six complete sealed attempts per lane qualify; development is ignored")
    func sixSealedAttemptsQualify() {
        let passing = aggregates(attemptCount: 6)
        let developmentFailure = aggregate(
            partition: .development,
            lane: .englishASR,
            attemptCount: 6,
            errorRate: 1
        )
        let passingGates = ScriptureQualificationGatePolicy.evaluate(
            passing + [developmentFailure]
        )
        #expect(ScriptureQualificationGatePolicy.qualifies(passingGates))
        #expect(passingGates.allSatisfy { $0.minimumAttempts == 6 })
    }

    @Test("five sealed attempts per lane cannot qualify")
    func fiveSealedAttemptsFail() {
        let gates = ScriptureQualificationGatePolicy.evaluate(
            aggregates(attemptCount: 5)
        )
        #expect(!ScriptureQualificationGatePolicy.qualifies(gates))
    }

    @Test("a failed threshold or missing lane cannot qualify")
    func incompleteOrInaccurateLanesFail() {
        var failing = aggregates(attemptCount: 6)
        failing[0] = aggregate(
            partition: .sealedBlindQualification,
            lane: .englishASR,
            attemptCount: 6,
            errorRate: 1
        )
        let failingGates = ScriptureQualificationGatePolicy.evaluate(failing)
        #expect(
            !ScriptureQualificationGatePolicy.qualifies(failingGates)
        )
        #expect(!ScriptureQualificationGatePolicy.qualifies(Array(failingGates.dropLast())))
    }

    private func aggregates(attemptCount: Int) -> [ScriptureQualificationAggregate] {
        ScriptureQualificationLane.allCases.map {
            aggregate(
                partition: .sealedBlindQualification,
                lane: $0,
                attemptCount: attemptCount,
                errorRate: 0
            )
        }
    }

    private func aggregate(
        partition: ScriptureQualificationPartition,
        lane: ScriptureQualificationLane,
        attemptCount: Int,
        errorRate: Double
    ) -> ScriptureQualificationAggregate {
        let referenceUnits = attemptCount * 100
        return ScriptureQualificationAggregate(
            partition: partition,
            lane: lane,
            metricUnit: lane.metricUnit,
            attemptCount: attemptCount,
            successCount: attemptCount,
            failureCount: 0,
            editCount: Int(errorRate * Double(referenceUnits)),
            referenceUnitCount: referenceUnits,
            errorRate: errorRate,
            referencePunctuationCount: attemptCount,
            hypothesisPunctuationCount: attemptCount,
            punctuationEditCount: 0,
            punctuationErrorRate: 0,
            audioSeconds: Double(attemptCount * 10),
            runtimeSeconds: Double(attemptCount),
            failureCounts: [:]
        )
    }
}
