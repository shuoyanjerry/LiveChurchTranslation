import Foundation
@testable import ModelDownloadHTTP
import Testing

@MainActor
struct MultifileDownloadFixture {
    let sandbox: TestDirectory
    let encoder: TestArtifact
    let vocabulary: TestArtifact
    let manifest: ModelDownloadManifest
    let transport: FakeModelHTTPTransport
    let locations: TestModelLocationStore
    let reporter: TestRuntimeReporter
    let downloader: HTTPModelDownloader

    init() throws {
        let directory = try TestDirectory()
        let encoderArtifact = try Self.artifact(
            remote: "https://example.com/encoder.onnx",
            path: "encoder.onnx",
            contents: "encoder"
        )
        let vocabularyArtifact = try Self.artifact(
            remote: "https://example.com/vocab.json",
            path: "tokenizer/vocab.json",
            contents: "vocabulary"
        )
        let modelManifest = try makeManifest(artifacts: [encoderArtifact, vocabularyArtifact])
        let modelTransport = FakeModelHTTPTransport(payloads: [
            encoderArtifact.remoteURL: encoderArtifact.data,
            vocabularyArtifact.remoteURL: vocabularyArtifact.data,
        ])
        let locationStore = TestModelLocationStore()
        let runtimeReporter = TestRuntimeReporter()
        sandbox = directory
        encoder = encoderArtifact
        vocabulary = vocabularyArtifact
        manifest = modelManifest
        transport = modelTransport
        locations = locationStore
        reporter = runtimeReporter
        downloader = try HTTPModelDownloader(
            manifests: [modelManifest],
            rootDirectory: directory.url,
            transport: modelTransport,
            locationStore: locationStore,
            runtimeReporter: runtimeReporter
        )
    }

    func verify(output: URL) async throws {
        let installedEncoder = try Data(
            contentsOf: output.appendingPathComponent("encoder.onnx")
        )
        let installedVocabulary = try Data(
            contentsOf: output.appendingPathComponent("tokenizer/vocab.json")
        )
        #expect(output.hasDirectoryPath)
        #expect(installedEncoder == encoder.data)
        #expect(installedVocabulary == vocabulary.data)
        let requestCount = await transport.requestCount()
        let registeredLocation = await locations.location(for: manifest.descriptor.id)
        #expect(requestCount == 2)
        #expect(registeredLocation == output)
        let status = await reporter.status(for: manifest.descriptor)
        #expect(status.state == .available(location: output))
    }

    func remove() {
        sandbox.remove()
    }

    private static func artifact(
        remote: String,
        path: String,
        contents: String
    ) throws -> TestArtifact {
        TestArtifact(
            remoteURL: try #require(URL(string: remote)),
            relativePath: path,
            data: Data(contents.utf8)
        )
    }
}
