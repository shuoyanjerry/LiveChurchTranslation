enum CandidatePauseSourceBoundaryValidator {
    static func validate(
        actual: [VADBoundaryRecord],
        expected: [CandidatePauseSourceBoundary],
        sourceAudioSeconds: Double
    ) throws -> CandidatePauseSourceReconciliation {
        guard actual.count == expected.count else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("boundary count mismatch")
        }
        var reconciliation = CandidatePauseSourceReconciliation()
        for (index, pair) in zip(actual, expected).enumerated() {
            reconciliation.add(
                try validate(
                    pair.0,
                    expected: pair.1,
                    index: index,
                    isLast: index == expected.count - 1,
                    sourceAudioSeconds: sourceAudioSeconds
                )
            )
        }
        return reconciliation
    }

    private static func validate(
        _ actual: VADBoundaryRecord,
        expected: CandidatePauseSourceBoundary,
        index: Int,
        isLast: Bool,
        sourceAudioSeconds: Double
    ) throws -> CandidatePauseSourceReconciliation {
        try require(actual.sequenceNumber == expected.sequenceNumber, field: "sequence", index: index)
        try require(actual.reason == expected.reason, field: "reason", index: index)
        try require(equal(actual.startedAtSeconds, expected.startedAtSeconds), field: "start", index: index)
        let emissionLagCount = try reconciledEmissionLag(
            actual,
            expected: expected,
            index: index,
            isLast: isLast
        )
        let exactEnd =
            equal(actual.endedAtSeconds, expected.endedAtSeconds)
            && equal(actual.durationSeconds, expected.durationSeconds)
        if exactEnd {
            return CandidatePauseSourceReconciliation(
                emissionLagCount: emissionLagCount
            )
        }
        let paddingSamples = try reconciledEndOfStreamPadding(
            actual,
            expected: expected,
            index: index,
            isLast: isLast,
            sourceAudioSeconds: sourceAudioSeconds
        )
        return CandidatePauseSourceReconciliation(
            paddingSamples: paddingSamples,
            emissionLagCount: emissionLagCount
        )
    }

    private static func reconciledEmissionLag(
        _ actual: VADBoundaryRecord,
        expected: CandidatePauseSourceBoundary,
        index: Int,
        isLast: Bool
    ) throws -> Int {
        if optionalEqual(
            actual.emissionLagAfterRetainedAudioSeconds,
            expected.emissionLagAfterRetainedAudioSeconds
        ) {
            return 0
        }
        try require(
            isLast && expected.reason == "endOfStream"
                && actual.emissionLagAfterRetainedAudioSeconds == nil
                && expected.emissionLagAfterRetainedAudioSeconds != nil,
            field: "emissionLag",
            index: index
        )
        return 1
    }

    private static func reconciledEndOfStreamPadding(
        _ actual: VADBoundaryRecord,
        expected: CandidatePauseSourceBoundary,
        index: Int,
        isLast: Bool,
        sourceAudioSeconds: Double
    ) throws -> Int {
        let endDelta = expected.endedAtSeconds - actual.endedAtSeconds
        let durationDelta = expected.durationSeconds - actual.durationSeconds
        let samples = Int((endDelta * 16_000).rounded())
        try require(
            isLast && expected.reason == "endOfStream"
                && equal(actual.endedAtSeconds, sourceAudioSeconds)
                && (1..<320).contains(samples)
                && equal(endDelta, Double(samples) / 16_000)
                && equal(durationDelta, endDelta),
            field: "end",
            index: index
        )
        return samples
    }

    private static func require(_ condition: Bool, field: String, index: Int) throws {
        guard condition else {
            throw CandidatePauseBenchmarkError.invalidSourceReport(
                "boundary \(field) mismatch at ordinal \(index + 1)"
            )
        }
    }

    private static func optionalEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): true
        case (.some(let lhs), .some(let rhs)): equal(lhs, rhs)
        default: false
        }
    }

    private static func equal(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 0.000_000_001
    }
}

struct CandidatePauseSourceReconciliation {
    private(set) var paddingSamples: Int
    private(set) var emissionLagCount: Int

    init(paddingSamples: Int = 0, emissionLagCount: Int = 0) {
        self.paddingSamples = paddingSamples
        self.emissionLagCount = emissionLagCount
    }

    mutating func add(_ value: Self) {
        paddingSamples += value.paddingSamples
        emissionLagCount += value.emissionLagCount
    }
}
