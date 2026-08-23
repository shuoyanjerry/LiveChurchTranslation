import Foundation
@testable import ModelDownloadHTTP
import Testing

extension ModelDiskSpacePreflightTests {
    @Test func concurrentDownloadsShareOneSafetyMargin() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let firstModel = try artifact(id: "first", contents: "12345678")
        let secondModel = try artifact(id: "second", contents: "abcdefgh")
        let firstManifest = try makeManifest(id: "first", artifacts: [firstModel])
        let secondManifest = try makeManifest(id: "second", artifacts: [secondModel])
        let transport = FakeModelHTTPTransport(
            payloads: [
                firstModel.remoteURL: firstModel.data,
                secondModel.remoteURL: secondModel.data,
            ],
            delay: .milliseconds(100)
        )
        let downloader = try testDownloader(
            manifests: [firstManifest, secondManifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter(),
            availableBytes: 21,
            diskSafetyMarginBytes: 5
        )

        async let first = downloader.ensureAvailable(firstManifest.descriptor)
        async let second = downloader.ensureAvailable(secondManifest.descriptor)
        _ = try await (first, second)

        #expect(await transport.requestCount() == 2)
    }

    @Test func failedTransferReleasesItsReservation() async throws {
        let sandbox = try TestDirectory()
        defer { sandbox.remove() }
        let failedModel = try artifact(id: "failed", contents: "12345678")
        let validModel = try artifact(id: "valid", contents: "abcdefgh")
        let failedManifest = try makeManifest(id: "failed", artifacts: [failedModel])
        let validManifest = try makeManifest(id: "valid", artifacts: [validModel])
        let transport = FakeModelHTTPTransport(
            payloads: [validModel.remoteURL: validModel.data]
        )
        let downloader = try testDownloader(
            manifests: [failedManifest, validManifest],
            rootDirectory: sandbox.url,
            transport: transport,
            locationStore: TestModelLocationStore(),
            runtimeReporter: TestRuntimeReporter(),
            availableBytes: 13,
            diskSafetyMarginBytes: 5
        )

        await expectModelDownloadError(.downloadFailed) {
            try await downloader.ensureAvailable(failedManifest.descriptor)
        }
        _ = try await downloader.ensureAvailable(validManifest.descriptor)

        #expect(await transport.requestCount() == 2)
    }
}
