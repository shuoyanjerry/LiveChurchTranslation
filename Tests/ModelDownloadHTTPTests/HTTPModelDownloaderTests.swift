import Foundation
import ModelDownloadAPI
@testable import ModelDownloadHTTP
import ModelRuntimeAPI
import Testing

@MainActor
@Suite struct HTTPModelDownloaderTests {
    @Test func installsMultifileDirectoryAndReportsAvailability() async throws {
        let fixture = try MultifileDownloadFixture()
        defer { fixture.remove() }

        let output = try await fixture.downloader.ensureAvailable(fixture.manifest.descriptor)
        let cachedOutput = try await fixture.downloader.ensureAvailable(fixture.manifest.descriptor)

        #expect(cachedOutput == output)
        try await fixture.verify(output: output)
    }

    @Test func returnsSingleFileAndReusesVerifiedArtifact() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("gguf-model".utf8)
        )
        let manifest = try makeManifest(
            id: "translation",
            artifacts: [model],
            result: .file(relativePath: "model.gguf")
        )
        let transport = FakeModelHTTPTransport(payloads: [model.remoteURL: model.data])
        let downloader = try HTTPModelDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter()
        )

        let first = try await downloader.ensureAvailable(manifest.descriptor)
        let second = try await downloader.ensureAvailable(manifest.descriptor)

        let installedData = try Data(contentsOf: first)
        #expect(first == second)
        #expect(installedData == model.data)
        let requestCount = await transport.requestCount()
        #expect(requestCount == 1)
        #expect(FileManager.default.fileExists(atPath: first.path + ".part") == false)
    }

    @Test func corruptArtifactIsReplaced() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("correct".utf8)
        )
        let manifest = try makeManifest(artifacts: [model])
        let installed = sandbox.url
            .appendingPathComponent("test-model", isDirectory: true)
            .appendingPathComponent("model.gguf")
        try FileManager.default.createDirectory(
            at: installed.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("corrupt".utf8).write(to: installed)
        let transport = FakeModelHTTPTransport(payloads: [model.remoteURL: model.data])
        let downloader = try HTTPModelDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter()
        )

        _ = try await downloader.ensureAvailable(manifest.descriptor)

        let installedData = try Data(contentsOf: installed)
        #expect(installedData == model.data)
        let requestCount = await transport.requestCount()
        #expect(requestCount == 1)
    }

    @Test func concurrentRequestsShareOneTransfer() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/model.gguf")),
            relativePath: "model.gguf",
            data: Data("shared".utf8)
        )
        let manifest = try makeManifest(artifacts: [model])
        let transport = FakeModelHTTPTransport(
            payloads: [model.remoteURL: model.data],
            delay: .milliseconds(100)
        )
        let downloader = try HTTPModelDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter()
        )

        async let first = downloader.ensureAvailable(manifest.descriptor)
        async let second = downloader.ensureAvailable(manifest.descriptor)
        let outputs = try await [first, second]

        #expect(outputs[0] == outputs[1])
        let requestCount = await transport.requestCount()
        #expect(requestCount == 1)
    }
}
