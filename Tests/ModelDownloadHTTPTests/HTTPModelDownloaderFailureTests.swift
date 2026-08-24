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
        let partialData = Data("slow".utf8)
        let transport = PartialFileSuspendingModelHTTPTransport(partialData: partialData)
        let downloader = try testDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: reporter
        )
        let operation = Task {
            try await downloader.ensureAvailable(manifest.descriptor)
        }
        await transport.waitUntilDownloadStarts()
        let installed = sandbox.url.appendingPathComponent("test-model/model.gguf")
        let partial = URL(fileURLWithPath: installed.path + ".part")
        #expect(try Data(contentsOf: partial) == partialData)

        await downloader.cancelDownload(for: manifest.descriptor.id)

        await expectModelDownloadError(.cancelled) { try await operation.value }
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
        let downloader = try testDownloader(
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
        let downloader = try testDownloader(
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

private actor PartialFileSuspendingModelHTTPTransport: ModelHTTPTransport {
    private let partialData: Data
    private var downloadStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    init(partialData: Data) {
        self.partialData = partialData
    }

    func download(
        from _: URL,
        to localURL: URL,
        maximumBytes: Int64,
        progress: @escaping ModelHTTPProgress
    ) async throws -> ModelHTTPTransferResult {
        guard Int64(partialData.count) < maximumBytes else {
            throw ModelHTTPTransportError.responseTooLarge(maximumBytes: maximumBytes)
        }
        try partialData.write(to: localURL)
        progress(Int64(partialData.count), maximumBytes)
        downloadStarted = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }

        while true {
            try await Task.sleep(for: .seconds(86_400))
        }
    }

    func waitUntilDownloadStarts() async {
        guard !downloadStarted else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }
}
