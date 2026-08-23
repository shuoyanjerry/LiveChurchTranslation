import Foundation
import ModelDownloadAPI
@testable import ModelDownloadHTTP
import ModelRuntimeAPI
import Testing

@MainActor
@Suite struct BundledModelProviderTests {
    @Test func returnsVerifiedBundleLocationWithoutAWebTransport() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let artifact = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("sealed model".utf8)
        )
        let manifest = try makeManifest(
            artifacts: [artifact],
            result: .file(relativePath: artifact.relativePath)
        )
        let directory = sandbox.url.appending(path: "test-model", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let expected = directory.appending(path: artifact.relativePath)
        try artifact.data.write(to: expected)
        let reporter = TestRuntimeReporter()
        let provider = try BundledModelProvider(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            runtimeReporter: reporter
        )

        let first = try await provider.ensureAvailable(manifest.descriptor)
        let second = try await provider.ensureAvailable(manifest.descriptor)

        #expect(first == expected)
        #expect(second == expected)
        let history = await reporter.history()
        guard case .available(let location) = history.last?.state else {
            Issue.record("Expected the bundled model to be reported as available")
            return
        }
        #expect(location == expected)
    }

    @Test func corruptBundledArtifactFailsClosedWithReinstallMessage() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let artifact = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("expected".utf8)
        )
        let manifest = try makeManifest(artifacts: [artifact])
        let directory = sandbox.url.appending(path: "test-model", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("corrupt".utf8).write(to: directory.appending(path: artifact.relativePath))
        let provider = try BundledModelProvider(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            runtimeReporter: TestRuntimeReporter()
        )

        await #expect(throws: BundledModelError.self) {
            _ = try await provider.ensureAvailable(manifest.descriptor)
        }
    }
}
