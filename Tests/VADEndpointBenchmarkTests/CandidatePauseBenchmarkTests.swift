import Foundation
import Testing

@Suite("Frozen candidate-pause shadow companion")
struct CandidatePauseBenchmarkTests {
    @Test(
        "writes a hash-bound shadow-only companion report",
        .enabled(
            if: environment["SERMON_WAV_DIR"] != nil
                && environment["VAD_CANDIDATE_PAUSE_SOURCE_REPORT"] != nil
                && environment["VAD_CANDIDATE_PAUSE_OUTPUT"] != nil,
            "Requires the frozen private WAV corpus, source report, and a fresh artifact path."
        )
    )
    func replayFrozenSelectedLane() async throws {
        try await CandidatePauseBenchmarkHarness.run(environment: Self.environment)
    }

    private static let environment = ProcessInfo.processInfo.environment
}
