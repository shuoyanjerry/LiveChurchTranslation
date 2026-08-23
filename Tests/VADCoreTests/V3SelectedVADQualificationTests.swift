import Foundation
import Testing

@Suite("V3 selected WebRTC manifest-aware shadow baseline")
struct V3SelectedVADQualificationTests {
    @Test(
        "preflights the frozen 128-track denominator without replay",
        .enabled(
            if: V3SelectedVADInputs.shouldPreflight(environment),
            "Requires explicit private v3 preflight opt-in in a Release test process."
        )
    )
    func preflightFrozenV3Corpus() throws {
        let inputs = try V3SelectedVADInputs(environment: Self.environment)
        let prepared = try V3SelectedVADPreflight().prepare(inputs)
        #expect(prepared.tracks.count == V3SelectedVADPolicy.trackCount)
        #expect(prepared.manifest.summary.logicalItemCount == V3SelectedVADPolicy.logicalItemCount)
        #expect(prepared.identity.productionSourceBundle.fileCount == 59)
        #expect(prepared.identity.harnessSourceBundle.fileCount > 0)
        print("V3_SELECTED_VAD_PREFLIGHT_LOGICAL_ITEMS=14")
        print("V3_SELECTED_VAD_PREFLIGHT_TRACKS=128")
        print("V3_SELECTED_VAD_PREFLIGHT_WAV_SET_SHA256=\(prepared.identity.wavSetSHA256)")
    }

    @Test(
        "replays all tracks with production-shadow parity and writes a private report",
        .enabled(
            if: V3SelectedVADInputs.shouldReplay(environment),
            "Requires a fresh private report output in a Release test process."
        )
    )
    func runFullSelectedWebRTCShadow() async throws {
        let inputs = try V3SelectedVADInputs(environment: Self.environment)
        let result = try await V3SelectedVADQualificationHarness.run(inputs: inputs)
        #expect(result.0.aggregates.overall.trackAttemptCount == 128)
        #expect(result.0.aggregates.overall.failureCount == 0)
        #expect(result.0.aggregates.genuineChurchSermons.trackAttemptCount == 8)
        #expect(result.0.aggregates.scriptedOrNarrationPrograms.trackAttemptCount == 120)
        #expect(result.0.releaseGate.accuracyEligible == false)
        #expect(result.0.releaseGate.releaseEligible == false)
    }

    private static let environment = ProcessInfo.processInfo.environment
}
