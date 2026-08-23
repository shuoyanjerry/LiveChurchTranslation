import ASRFunASRNano
import ASRQwen3
import Foundation
import Testing

@Suite("Fun-ASR-Nano same-machine qualification")
struct FunASRNanoABQualificationTests {
    @Test(
        "records fixed-clip A/B evidence without changing production default",
        .enabled(if: Self.hasEnvironment, "Requires FUNASR/QWEN model and fixture paths.")
    )
    func recordsABEvidenceWhenSupplied() async throws {
        guard
            let context = try ASRBenchmarkABContext(
                environment: ProcessInfo.processInfo.environment
            )
        else { return }
        let fun = FunASRNanoProvider(
            configuration: FunASRNanoConfiguration(staticHotwords: context.terms)
        )
        let qwen = Qwen3ASRProvider()
        let comparison = try await ASRBenchmarkQualificationRunner.compare(
            funASR: fun,
            qwen: qwen,
            directories: context.directories,
            input: context.runInput
        )

        let report = ASRBenchmarkReport(
            generatedAt: Date(),
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            processorCount: ProcessInfo.processInfo.processorCount,
            sherpaVersion: "1.13.6",
            modelAssetRevision: "github-release-asset-394517157",
            loads: comparison.loads,
            observations: comparison.observations
        )
        try save(report, to: context.outputURL)
        #expect(comparison.observations.count == context.expectedObservationCount)
        #expect(
            comparison.observations.filter { $0.fixture == "synthetic-silence" }.allSatisfy {
                $0.error != nil && $0.rawText.isEmpty
            })
    }

    private func save(_ report: ASRBenchmarkReport, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(report).write(to: url, options: .atomic)
    }

    private static let hasEnvironment = {
        let environment = ProcessInfo.processInfo.environment
        return ["FUNASR_MODEL_DIR", "QWEN_MODEL_DIR", "ASR_AB_MANIFEST", "ASR_AB_OUTPUT"]
            .allSatisfy { environment[$0] != nil }
    }()
}
