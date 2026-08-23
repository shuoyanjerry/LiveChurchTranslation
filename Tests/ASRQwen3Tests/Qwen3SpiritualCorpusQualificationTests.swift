import Foundation
import Testing

@Suite("Qwen3 frozen spiritual-corpus qualification")
struct Qwen3SpiritualCorpusQualificationTests {
    @Test(
        "replays every frozen Manifest V2 segment through the production adapter",
        .enabled(if: Self.hasEnvironment, "Requires all five Qwen qualification inputs.")
    )
    func replaysFrozenCorpusWhenSupplied() async throws {
        let environment = ProcessInfo.processInfo.environment
        let inputs = try QwenQualificationInputs(environment: environment)
        let report = try await QwenQualificationRunner().run(
            inputs: inputs,
            processEnvironment: environment
        )
        try QwenQualificationReportWriter.write(report, to: inputs.reportURL)

        #expect(report.schemaVersion == 3)
        #expect(
            report.qualificationManifestSHA256
                == QwenQualificationConfiguration.frozenManifestSHA256
        )
        #expect(report.aggregate.clipCount == 6)
        #expect(report.aggregate.timing.attemptCount == 220)
    }

    fileprivate static var hasEnvironment: Bool {
        let environment = ProcessInfo.processInfo.environment
        return requiredEnvironmentKeys.allSatisfy { key in
            guard let value = environment[key] else { return false }
            return !value.isEmpty
        }
    }

    private static let requiredEnvironmentKeys = [
        "QWEN_MODEL_DIR",
        "MANDARIN_ASR_QUALIFICATION_MANIFEST",
        "MANDARIN_ASR_REFERENCE_MANIFEST",
        "MANDARIN_ASR_WAV_DIR",
        "QWEN_ASR_REPORT",
    ]
}
