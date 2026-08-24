import Foundation
@testable import ModelDownloadHTTP
import Testing

@MainActor
@Suite struct HTTPModelDownloaderCancellationRaceTests {
    @Test func preCancelledCallerCannotCreateAnUnstructuredDownload() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("payload".utf8)
        )
        let manifest = try makeManifest(artifacts: [model])
        let downloader = try testDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: FakeModelHTTPTransport(payloads: [model.remoteURL: model.data]),
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter()
        )

        let operation = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await downloader.ensureAvailable(manifest.descriptor)
        }
        do {
            _ = try await operation.value
            Issue.record("Expected the pre-cancelled request to fail")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected cancellation error: \(error)")
        }

        let installed = sandbox.url.appendingPathComponent("test-model/model.gguf")
        expectNoPublishedArtifact(at: installed)
    }
}
