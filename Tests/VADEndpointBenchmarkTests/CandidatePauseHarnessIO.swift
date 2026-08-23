import Foundation

struct CandidatePauseHarnessInput {
    let workspace: URL
    let wavDirectory: URL
    let sourceReport: URL
    let output: URL

    init?(environment: [String: String]) {
        guard let wav = environment["SERMON_WAV_DIR"],
            let source = environment["VAD_CANDIDATE_PAUSE_SOURCE_REPORT"],
            let destination = environment["VAD_CANDIDATE_PAUSE_OUTPUT"]
        else { return nil }
        workspace = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        wavDirectory = URL(fileURLWithPath: wav, isDirectory: true)
        sourceReport = URL(fileURLWithPath: source)
        output = URL(fileURLWithPath: destination)
    }

    func privateValues(entries: [VADCorpusEntry]) -> [String] {
        [wavDirectory.path, sourceReport.path, output.path]
            + entries.flatMap { [$0.fileName, $0.url.path] }
    }
}

enum CandidatePauseHarnessOutput {
    static func write(
        _ data: Data,
        aggregate: CandidatePauseAggregate,
        input: CandidatePauseHarnessInput
    ) throws {
        let written = try CandidatePausePrivateWriter.write(
            data,
            workspaceRoot: input.workspace,
            output: input.output
        )
        let fingerprint = try VADBenchmarkCorpus.fingerprint(written)
        CandidatePauseBenchmarkConsole.printSummary(
            aggregate,
            artifactSHA256: fingerprint.sha256,
            mode: try fileMode(written)
        )
    }

    private static func fileMode(_ url: URL) throws -> UInt16 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let value = attributes[.posixPermissions] as? NSNumber else {
            throw CandidatePauseBenchmarkError.storageFailure
        }
        return value.uint16Value
    }
}
