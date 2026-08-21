import Foundation
import ModelDownloadAPI
@testable import ModelDownloadHTTP
import ModelRuntimeAPI
import Testing

@MainActor
@Suite struct HTTPModelDownloaderFailureTests {
    @Test func cancellationRemovesPartialFileAndReportsFailure() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("slow model".utf8)
        )
        let manifest = try makeManifest(artifacts: [model])
        let reporter = TestRuntimeReporter()
        let downloader = try HTTPModelDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: FakeModelHTTPTransport(
                payloads: [model.remoteURL: model.data],
                delay: .seconds(5)
            ),
            locationStore: TestModelLocationStore(),
            runtimeReporter: reporter
        )
        let operation = Task {
            try await downloader.ensureAvailable(manifest.descriptor)
        }
        try await Task.sleep(for: .milliseconds(100))

        await downloader.cancelDownload(for: manifest.descriptor.id)

        await expectModelDownloadError(.cancelled) { try await operation.value }
        let installed = sandbox.url.appendingPathComponent("test-model/model.gguf")
        expectNoPublishedArtifact(at: installed)
        let state = (await reporter.status(for: manifest.descriptor)).state
        guard case .failed = state else {
            Issue.record("Expected failed state.")
            return
        }
    }

    @Test func lengthMismatchFailsWithoutPublishingArtifact() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("payload".utf8)
        )
        let manifest = try makeManifest(artifacts: [model])
        let downloader = try HTTPModelDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: FakeModelHTTPTransport(
                payloads: [model.remoteURL: model.data],
                reportedLengthOffset: 1
            ),
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter()
        )

        await expectModelDownloadError(.invalidArtifact) {
            try await downloader.ensureAvailable(manifest.descriptor)
        }
        let installed = sandbox.url.appendingPathComponent("test-model/model.gguf")
        expectNoPublishedArtifact(at: installed)
    }

    @Test func rejectsSymlinkedInstallDirectory() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let outside = try TestDirectory()
        defer { outside.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("payload".utf8)
        )
        let manifest = try makeManifest(artifacts: [model])
        try FileManager.default.createSymbolicLink(
            at: sandbox.url.appendingPathComponent("test-model"),
            withDestinationURL: outside.url
        )
        let downloader = try HTTPModelDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: FakeModelHTTPTransport(payloads: [model.remoteURL: model.data]),
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter()
        )

        await expectModelDownloadError(.invalidArtifact) {
            try await downloader.ensureAvailable(manifest.descriptor)
        }
        #expect(
            FileManager.default.fileExists(
                atPath: outside.url.appendingPathComponent("model.gguf").path
            ) == false
        )
    }
}
