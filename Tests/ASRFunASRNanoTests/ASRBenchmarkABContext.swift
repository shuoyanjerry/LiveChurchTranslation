import Foundation

struct ASRBenchmarkABContext {
    let directories: ASRBenchmarkModelDirectories
    let outputURL: URL
    let runInput: ASRBenchmarkRunInput
    let terms: String
    let expectedObservationCount: Int

    init?(environment: [String: String]) throws {
        guard
            let funPath = environment["FUNASR_MODEL_DIR"],
            let qwenPath = environment["QWEN_MODEL_DIR"],
            let manifestPath = environment["ASR_AB_MANIFEST"],
            let outputPath = environment["ASR_AB_OUTPUT"]
        else { return nil }
        let fixtures = try JSONDecoder().decode(
            [ASRBenchmarkFixture].self,
            from: Data(contentsOf: URL(fileURLWithPath: manifestPath))
        )
        var seen = Set<String>()
        terms =
            fixtures
            .flatMap(\.expectedTerms)
            .filter { seen.insert($0).inserted }
            .joined(separator: ",")
        directories = ASRBenchmarkModelDirectories(
            funASR: URL(fileURLWithPath: funPath),
            qwen: URL(fileURLWithPath: qwenPath)
        )
        outputURL = URL(fileURLWithPath: outputPath)
        runInput = ASRBenchmarkRunInput(
            fixtures: fixtures,
            projectRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
            contextPrompt: terms
        )
        expectedObservationCount = (fixtures.count + 1) * 2
    }
}
