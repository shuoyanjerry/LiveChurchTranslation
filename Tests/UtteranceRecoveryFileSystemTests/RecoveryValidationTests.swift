import Testing
import UtteranceRecoveryAPI
import UtteranceRecoveryFileSystem

@Suite struct RecoveryValidationTests {
    @Test func rejectsEmptySamples() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()

        await #expect(throws: UtteranceRecoveryError.emptySamples) {
            try await store.stage(fixture.segment(samples: []), for: fixture.sessionID)
        }
    }

    @Test func rejectsNonFiniteSamples() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()

        await #expect(throws: UtteranceRecoveryError.nonFiniteSample(index: 1)) {
            try await store.stage(
                fixture.segment(samples: [0, .infinity]),
                for: fixture.sessionID
            )
        }
    }

    @Test func rejectsSampleCountAboveBound() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let limits = UtteranceRecoveryLimits(
            maximumSampleCount: 2,
            maximumWAVFileBytes: 1_000
        )
        let store = try fixture.store(limits: limits)

        await #expect(
            throws: UtteranceRecoveryError.sampleCountExceeded(actual: 3, maximum: 2)
        ) {
            try await store.stage(fixture.segment(), for: fixture.sessionID)
        }
    }

    @Test func rejectsWAVAboveFileBound() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let limits = UtteranceRecoveryLimits(
            maximumSampleCount: 10,
            maximumWAVFileBytes: 48
        )
        let store = try fixture.store(limits: limits)

        await #expect(
            throws: UtteranceRecoveryError.audioFileSizeExceeded(actual: 56, maximum: 48)
        ) {
            try await store.stage(fixture.segment(), for: fixture.sessionID)
        }
    }

    @Test func rejectsMalformedRateAndTiming() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()

        await #expect(throws: UtteranceRecoveryError.invalidSampleRate(16_000.5)) {
            try await store.stage(
                fixture.segment(sampleRate: 16_000.5),
                for: fixture.sessionID
            )
        }
        await #expect(throws: UtteranceRecoveryError.invalidTiming) {
            try await store.stage(
                fixture.segment(startedAt: .seconds(2), endedAt: .seconds(1)),
                for: fixture.sessionID
            )
        }
    }
}
