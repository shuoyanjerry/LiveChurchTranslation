import Foundation
import Testing

@Suite("V3 selected WebRTC private writer")
struct V3SelectedVADWriterTests {
    @Test func writesPrivateNoReplaceOutput() throws {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory.appendingPathComponent(
            "v3-selected-vad-writer-\(UUID().uuidString)",
            isDirectory: true
        )
        let workspace = temporary.resolvingSymlinksInPath().standardizedFileURL
        defer { try? manager.removeItem(at: workspace) }
        try manager.createDirectory(at: workspace, withIntermediateDirectories: false)
        let artifacts = workspace.appendingPathComponent(".artifacts", isDirectory: true)
        try manager.createDirectory(at: artifacts, withIntermediateDirectories: false)
        try manager.setAttributes(
            [.posixPermissions: NSNumber(value: UInt16(0o700))],
            ofItemAtPath: artifacts.path
        )
        let output = workspace.appendingPathComponent(
            ".artifacts/v3-selected-vad/static-writer.json"
        )
        let inputs = try V3SelectedVADInputs(
            environment: [V3SelectedVADInputs.outputKey: output.path],
            workspaceRoot: workspace
        )
        let data = Data("{\"safe\":true}".utf8)
        let fingerprint = try V3SelectedVADPrivateWriter.write(data, inputs: inputs)
        let actual = try V3SelectedVADHashing.fingerprint(output)
        #expect(fingerprint == actual)
        #expect(try permissions(output) == 0o600)
        #expect(try permissions(output.deletingLastPathComponent()) == 0o700)
        #expect(throws: V3SelectedVADError.storageFailure) {
            try V3SelectedVADPrivateWriter.write(data, inputs: inputs)
        }
    }

    @Test func rejectsUnknownEnvironmentAndOutputEscape() {
        #expect(throws: V3SelectedVADError.unsupportedEnvironment("V3_SELECTED_VAD_UNKNOWN")) {
            try V3SelectedVADInputs(environment: ["V3_SELECTED_VAD_UNKNOWN": "1"])
        }
        #expect(throws: V3SelectedVADError.unsafeOutput) {
            try V3SelectedVADInputs(
                environment: [V3SelectedVADInputs.outputKey: "/tmp/escaped.json"]
            )
        }
    }

    private func permissions(_ url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let value = try #require(attributes[.posixPermissions] as? NSNumber)
        return value.intValue
    }
}
