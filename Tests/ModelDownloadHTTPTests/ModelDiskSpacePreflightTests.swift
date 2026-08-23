import Foundation
import ModelDownloadAPI
@testable import ModelDownloadHTTP
import Testing

@MainActor
@Suite struct ModelDiskSpacePreflightTests {}

extension ModelDiskSpacePreflightTests {
    @Test func verifiedModelDoesNotRequireFreeCapacity() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = try artifact(id: "installed", contents: "already installed")
        let manifest = try makeManifest(id: "installed", artifacts: [model])
        let installed = sandbox.url.appendingPathComponent("installed/model.bin")
        try FileManager.default.createDirectory(
            at: installed.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try model.data.write(to: installed)
        let transport = FakeModelHTTPTransport(payloads: [:])
        let downloader = try testDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter(),
            availableBytes: 0,
            diskSafetyMarginBytes: 100
        )

        _ = try await downloader.ensureAvailable(manifest.descriptor)

        #expect(try Data(contentsOf: installed) == model.data)
        #expect(await transport.requestCount() == 0)
    }

    @Test func partialInstallChargesOnlyMissingArtifacts() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let installedModel = try artifact(id: "encoder", contents: "encoder")
        let missingModel = try artifact(id: "decoder", contents: "0123456789")
        let manifest = try makeManifest(
            id: "partial",
            artifacts: [installedModel, missingModel]
        )
        let installed = sandbox.url.appendingPathComponent("partial/encoder.bin")
        try FileManager.default.createDirectory(
            at: installed.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try installedModel.data.write(to: installed)
        let transport = FakeModelHTTPTransport(
            payloads: [missingModel.remoteURL: missingModel.data]
        )
        let downloader = try testDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter(),
            availableBytes: Int64(missingModel.data.count) + 5,
            diskSafetyMarginBytes: 5
        )

        _ = try await downloader.ensureAvailable(manifest.descriptor)

        #expect(await transport.requestCount() == 1)
        #expect(try Data(contentsOf: installed) == installedModel.data)
    }

    @Test func insufficientCapacityFailsBeforeTransport() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let model = try artifact(id: "too-large", contents: "0123456789")
        let manifest = try makeManifest(id: "too-large", artifacts: [model])
        let transport = FakeModelHTTPTransport(payloads: [model.remoteURL: model.data])
        let reporter = TestRuntimeReporter()
        let downloader = try testDownloader(
            manifests: [manifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: reporter,
            availableBytes: 14,
            diskSafetyMarginBytes: 5
        )

        await expectInsufficientDiskSpace(
            requiredBytes: 15,
            availableBytes: 14
        ) {
            try await downloader.ensureAvailable(manifest.descriptor)
        }

        #expect(await transport.requestCount() == 0)
        expectNoPublishedArtifact(
            at: sandbox.url.appendingPathComponent("too-large/model.bin")
        )
        guard case .failed = (await reporter.status(for: manifest.descriptor)).state else {
            Issue.record("Expected the runtime reporter to publish the preflight failure")
            return
        }
    }

    func artifact(id: String, contents: String) throws -> TestArtifact {
        TestArtifact(
            remoteURL: try #require(URL(string: "https://example.com/\(id).bin")),
            relativePath: "\(id == "installed" || id == "too-large" ? "model" : id).bin",
            data: Data(contents.utf8)
        )
    }
}

@MainActor
private func expectInsufficientDiskSpace(
    requiredBytes: Int64,
    availableBytes: Int64,
    operation: () async throws -> URL
) async {
    do {
        _ = try await operation()
        Issue.record("Expected the disk preflight to reject the download")
    } catch let error as ModelDownloadError {
        #expect(
            error
                == .insufficientDiskSpace(
                    requiredBytes: requiredBytes,
                    availableBytes: availableBytes
                )
        )
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
