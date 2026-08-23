import ASRQualificationSupport
import Foundation
import Testing

@Suite struct ManifestToolRunnerTests {
    @Test func verifiesWAVAndAtomicallyWritesStrictManifest() throws {
        let workspace = try ManifestToolWorkspace()
        defer { workspace.remove() }
        try workspace.writeInputs()

        let result = try ASRQualificationManifestTool(expectedSegmentCount: 1).run(
            workspace.inputs
        )
        let data = try Data(contentsOf: workspace.outputURL)
        let manifest = try ASRQualificationManifestDecoder().decode(data)

        #expect(result.clipCount == 1)
        #expect(result.segmentCount == 1)
        #expect(manifest.clips[0].id == "clip-a")
        #expect(manifest.clips[0].allowsHypothesisEdgeInsertions)
    }

    @Test func leavesExistingOutputUntouchedOnPCMFailure() throws {
        let workspace = try ManifestToolWorkspace()
        defer { workspace.remove() }
        try workspace.writeInputs(pcmSHA256: String(repeating: "f", count: 64))
        let sentinel = Data("existing-output".utf8)
        try sentinel.write(to: workspace.outputURL)

        do {
            _ = try ASRQualificationManifestTool(expectedSegmentCount: 1).run(
                workspace.inputs
            )
            Issue.record("Expected exact PCM hash failure")
        } catch let error as ASRQualificationError {
            guard case .pcmSHA256Mismatch = error else {
                Issue.record("Unexpected ASR qualification error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(try Data(contentsOf: workspace.outputURL) == sentinel)
    }
}
