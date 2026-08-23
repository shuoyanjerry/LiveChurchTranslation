import Foundation
import Testing

@Suite("Candidate-pause private report storage")
struct CandidatePauseWriterTests {
    @Test func writesMode0600AndRefusesReplacement() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let output = root.appendingPathComponent(
            ".artifacts/vad-benchmarks/candidate-pause-test.json"
        )
        let written = try CandidatePausePrivateWriter.write(
            Data("synthetic".utf8),
            workspaceRoot: root,
            output: output
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: written.path)
        let mode = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(mode.uint16Value == 0o600)
        let directory = written.deletingLastPathComponent()
        let directoryAttributes = try FileManager.default.attributesOfItem(atPath: directory.path)
        let directoryMode = try #require(directoryAttributes[.posixPermissions] as? NSNumber)
        #expect(directoryMode.uint16Value == 0o700)
        #expect(throws: CandidatePauseBenchmarkError.storageFailure) {
            try CandidatePausePrivateWriter.write(
                Data("replacement".utf8),
                workspaceRoot: root,
                output: output
            )
        }
    }

    @Test func rejectsOutputOutsideArtifactDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(throws: CandidatePauseBenchmarkError.unsafeOutput) {
            try CandidatePausePrivateWriter.write(
                Data(),
                workspaceRoot: root,
                output: root.appendingPathComponent("outside.json")
            )
        }
    }
}
