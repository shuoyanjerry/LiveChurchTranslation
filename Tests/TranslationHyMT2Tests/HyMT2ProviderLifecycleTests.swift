import Foundation
@testable import TranslationHyMT2
import Testing

@MainActor
@Suite struct HyMT2ProviderLifecycleTests {
    @Test func loadsDirectoryWaitsForHealthAndAvoidsReload() async throws {
        let model = try TemporaryGGUF()
        defer { model.remove() }
        let server = FakeLlamaServerController()
        let transport = FakeLlamaServerTransport(healthFailures: 2)
        let provider = provider(server: server, transport: transport)

        try await provider.loadModel(at: model.directoryURL)
        try await provider.loadModel(at: model.directoryURL)

        let launches = await server.launchRequests()
        #expect(launches.count == 1)
        #expect(launches.first?.modelURL == model.fileURL)
        #expect(launches.first?.endpoint == HyMT2TestSupport.endpoint)
        let healthCount = await transport.checkedHealthCount()
        #expect(healthCount == 3)
    }

    @Test func shutdownStopsHelperAndMakesTranslateFail() async throws {
        let model = try TemporaryGGUF()
        defer { model.remove() }
        let server = FakeLlamaServerController()
        let provider = provider(
            server: server,
            transport: FakeLlamaServerTransport()
        )
        try await provider.loadModel(at: model.fileURL)

        await provider.shutdown()

        let isRunning = await server.isRunning()
        #expect(!isRunning)
        do {
            _ = try await provider.translate(
                .init(sourceText: "恩典", glossary: [])
            )
            Issue.record("Expected translation to fail after shutdown")
        } catch let error as HyMT2Error {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func surfacesEarlyHelperTermination() async throws {
        let model = try TemporaryGGUF()
        defer { model.remove() }
        let server = FakeLlamaServerController(remainsRunningAfterLaunch: false)
        let provider = provider(
            server: server,
            transport: FakeLlamaServerTransport()
        )

        do {
            try await provider.loadModel(at: model.fileURL)
            Issue.record("Expected early termination")
        } catch let error as HyMT2Error {
            #expect(error == .serverTerminated)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func surfacesHealthTimeout() async throws {
        let model = try TemporaryGGUF()
        defer { model.remove() }
        let server = FakeLlamaServerController()
        let transport = FakeLlamaServerTransport(healthFailures: .max)
        let configuration = HyMT2TestSupport.configuration(
            startupTimeout: .milliseconds(8),
            healthPollInterval: .milliseconds(1)
        )
        let provider = HyMT2TranslationProvider(
            configuration: configuration,
            server: server,
            transport: transport,
            endpointFactory: { HyMT2TestSupport.endpoint }
        )

        do {
            try await provider.loadModel(at: model.fileURL)
            Issue.record("Expected startup timeout")
        } catch let error as HyMT2Error {
            guard case .startupTimedOut = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let isRunning = await server.isRunning()
        #expect(!isRunning)
    }

    @Test func rejectsMissingModelBeforeLaunchingHelper() async {
        let server = FakeLlamaServerController()
        let provider = provider(
            server: server,
            transport: FakeLlamaServerTransport()
        )
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        do {
            try await provider.loadModel(at: missing)
            Issue.record("Expected missing model error")
        } catch let error as HyMT2Error {
            guard case .modelUnavailable = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let launches = await server.launchRequests()
        #expect(launches.isEmpty)
    }

    private func provider(
        server: FakeLlamaServerController,
        transport: FakeLlamaServerTransport
    ) -> HyMT2TranslationProvider {
        HyMT2TranslationProvider(
            configuration: HyMT2TestSupport.configuration(),
            server: server,
            transport: transport,
            endpointFactory: { HyMT2TestSupport.endpoint }
        )
    }
}
