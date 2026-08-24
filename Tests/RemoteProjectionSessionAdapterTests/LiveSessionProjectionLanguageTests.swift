import Foundation
import RemoteProjectionSessionAdapter
import SessionManagementAPI
import Testing

@Suite("Live session projection language metadata")
struct LiveSessionProjectionLanguageTests {
    @Test("Projects a language pair learned after the session begins")
    func projectsDelayedLanguagePair() async throws {
        let sessionID = UUID()
        let controller = ProjectionSessionControllerFake(
            initial: initialSnapshot(sessionID: sessionID)
        )
        let projection = ProjectionUpdateFake()
        let adapter = LiveSessionProjectionAdapter(controller: controller, projection: projection)

        await adapter.start()
        try await waitUntil { await projection.messages().count == 1 }
        await controller.emit(.stateChanged(languageSnapshot(sessionID: sessionID)))
        try await waitUntil {
            let pair = await projection.latestStateLanguagePair()
            return pair?.0 == "en" && pair?.1 == "zh-Hans"
        }

        #expect(await projection.sessions() == [sessionID])
        let pair = try #require(await projection.latestStateLanguagePair())
        #expect(pair.0 == "en")
        #expect(pair.1 == "zh-Hans")
        #expect(await projection.entries().isEmpty)
    }

    private func initialSnapshot(sessionID: UUID) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: sessionID,
            phase: .requestingPermission,
            transcript: [],
            modelStatus: nil,
            statusMessage: "Requesting permission"
        )
    }

    private func languageSnapshot(sessionID: UUID) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: sessionID,
            phase: .preparingModel,
            transcript: [],
            sourceLanguage: "en",
            targetLanguage: "zh-Hans",
            modelStatus: nil,
            statusMessage: "Preparing"
        )
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw ProjectionAdapterTestError.timedOut
    }
}
