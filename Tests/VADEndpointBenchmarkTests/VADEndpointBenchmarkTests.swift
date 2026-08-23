import Foundation
import Testing

@Suite("Private sermon endpoint A/B")
struct VADEndpointBenchmarkTests {
    @Test(
        "writes a reproducible per-file endpoint report",
        .enabled(
            if: environment["SERMON_WAV_DIR"] != nil
                && environment["VAD_BENCHMARK_OUTPUT"] != nil,
            "Requires private WAV input and an explicit ignored report path."
        )
    )
    func compareStrategies() async throws {
        guard let directory = Self.environment["SERMON_WAV_DIR"],
            let output = Self.environment["VAD_BENCHMARK_OUTPUT"]
        else { return }
        let entries = try VADBenchmarkCorpus.entries(
            in: URL(fileURLWithPath: directory, isDirectory: true)
        )
        let strategies = try VADBenchmarkStrategy.selected(
            from: Self.environment["VAD_BENCHMARK_STRATEGIES"]
        )
        var reports: [VADStrategyReport] = []
        for strategy in strategies {
            reports.append(try await benchmark(strategy, entries: entries))
        }
        try write(
            VADBenchmarkDocument(
                generatedAt: Date(),
                environment: VADBenchmarkEnvironmentMetadata.current(),
                caveats: Self.caveats,
                strategies: reports
            ), to: URL(fileURLWithPath: output))
    }

    private func benchmark(
        _ strategy: VADBenchmarkStrategy,
        entries: [VADCorpusEntry]
    ) async throws -> VADStrategyReport {
        var files: [VADFileReport] = []
        for entry in entries {
            let report = try await VADBenchmarkRunner().replay(entry, strategy: strategy)
            files.append(report)
            print("VAD_AB_\(strategy.rawValue)_\(entry.id)=\(report.metrics.consoleSummary)")
        }
        let aggregate = VADMetricsReport(files: files)
        print("VAD_AB_\(strategy.rawValue)_TOTAL=\(aggregate.consoleSummary)")
        return VADStrategyReport(
            strategy: strategy.rawValue,
            configuration: strategy.metadata,
            files: files,
            aggregate: aggregate,
            residentBytesAtCompletion: VADBenchmarkMemory.residentBytes(),
            processPeakResidentBytesAtCompletion: VADBenchmarkMemory.peakResidentBytes()
        )
    }

    private func write(_ report: VADBenchmarkDocument, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: url, options: .atomic)
    }

    private static let environment = ProcessInfo.processInfo.environment
    private static let caveats = [
        "maximumDuration is a structural unsafe-cut proxy, not a manually labeled unsafe cut.",
        "Emission lag starts at retained audio end, not a human-annotated sentence boundary.",
        "End-of-stream and negative synthetic-padding offsets are excluded from lag percentiles.",
        "Detector RTF excludes file hashing and decode but includes actor and segmentation overhead.",
        "Resident memory includes the test host; process peak is cumulative across strategy order.",
    ]
}
