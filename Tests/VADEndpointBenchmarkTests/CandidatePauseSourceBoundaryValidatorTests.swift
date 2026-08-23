import Testing

@Suite("Frozen source-boundary reconciliation")
struct CandidatePauseSourceValidatorTests {
    @Test func acceptsOnlySampleExactLegacyEOFPaddingAndLagPolicy() throws {
        let actualEnd = 1.003_25
        let paddingSamples = 268
        let expectedEnd = actualEnd + Double(paddingSamples) / 16_000
        let reconciliation = try CandidatePauseSourceBoundaryValidator.validate(
            actual: [boundary(end: actualEnd, duration: actualEnd, reason: "endOfStream", lag: nil)],
            expected: [
                sourceBoundary(
                    end: expectedEnd,
                    duration: expectedEnd,
                    reason: "endOfStream",
                    lag: 0
                )
            ],
            sourceAudioSeconds: actualEnd
        )
        #expect(reconciliation.paddingSamples == paddingSamples)
        #expect(reconciliation.emissionLagCount == 1)
    }

    @Test func rejectsIdenticalDriftForNonEOFBoundary() {
        #expect(throws: CandidatePauseBenchmarkError.self) {
            _ = try CandidatePauseSourceBoundaryValidator.validate(
                actual: [boundary(end: 1, duration: 1, reason: "softSilence", lag: 0.2)],
                expected: [
                    sourceBoundary(
                        end: 1.01,
                        duration: 1.01,
                        reason: "softSilence",
                        lag: 0.2
                    )
                ],
                sourceAudioSeconds: 1
            )
        }
    }

    @Test func rejectsFullAnalysisWindowAsLegacyPadding() {
        #expect(throws: CandidatePauseBenchmarkError.self) {
            _ = try CandidatePauseSourceBoundaryValidator.validate(
                actual: [boundary(end: 1, duration: 1, reason: "endOfStream", lag: nil)],
                expected: [
                    sourceBoundary(
                        end: 1.02,
                        duration: 1.02,
                        reason: "endOfStream",
                        lag: 0
                    )
                ],
                sourceAudioSeconds: 1
            )
        }
    }

    private func boundary(
        end: Double,
        duration: Double,
        reason: String,
        lag: Double?
    ) -> VADBoundaryRecord {
        VADBoundaryRecord(
            sequenceNumber: 1,
            startSample: 0,
            endSample: Int((end * 16_000).rounded()),
            validSampleCount: Int((end * 16_000).rounded()),
            pcmSHA256: String(repeating: "a", count: 64),
            startedAtSeconds: 0,
            endedAtSeconds: end,
            durationSeconds: duration,
            reason: reason,
            signedEmissionOffsetSeconds: lag ?? 0,
            emissionLagAfterRetainedAudioSeconds: lag,
            syntheticPaddingSamplesAtEmission: 0
        )
    }

    private func sourceBoundary(
        end: Double,
        duration: Double,
        reason: String,
        lag: Double?
    ) -> CandidatePauseSourceBoundary {
        CandidatePauseSourceBoundary(
            sequenceNumber: 1,
            startedAtSeconds: 0,
            endedAtSeconds: end,
            durationSeconds: duration,
            reason: reason,
            emissionLagAfterRetainedAudioSeconds: lag
        )
    }
}
