import AudioCaptureAPI
import Foundation
import RemoteProjectionSessionAdapter
import RemoteSharingAPI
import SessionManagementAPI
import Testing
import TranscriptAPI

@Suite("Live session projection adapter")
struct LiveSessionProjectionAdapterTests {
    @Test("Projects the current snapshot and redacts local failure detail")
    func projectsSnapshotAndRedactsFailure() async throws {
        let entry = makeEntry()
        let sessionID = UUID()
        let controller = ProjectionSessionControllerFake(
            initial: LiveSessionSnapshot(
                sessionID: sessionID,
                phase: .listening,
                transcript: [entry],
                sourceLanguage: "zh-Hans",
                targetLanguage: "en",
                modelStatus: nil,
                statusMessage: "Listening"
            )
        )
        let projection = ProjectionUpdateFake()
        let adapter = LiveSessionProjectionAdapter(
            controller: controller,
            projection: projection
        )

        await adapter.start()
        try await waitUntil { await projection.entries().count == 1 }
        await controller.emit(.stateChanged(makeFailedSnapshot(entry: entry)))
        try await waitUntil { await projection.messages().last == "已暂停" }

        #expect(await projection.sessions() == [sessionID])
        #expect(await projection.entries().first?.targetText == "Salvation is by grace.")
        #expect(await projection.entries().first?.sourceLanguage == "zh-Hans")
        #expect(await projection.entries().first?.targetLanguage == "en")
        #expect((await projection.messages()).contains("直播中"))
        #expect(!(await projection.messages()).contains { $0.contains("/Users/") })
    }

    private func makeEntry() -> TranscriptEntry {
        TranscriptEntry(
            sequence: 1,
            sourceText: "救恩本乎恩典",
            targetText: "Salvation is by grace.",
            startedMilliseconds: 0,
            endedMilliseconds: 1_000,
            translationMilliseconds: 50
        )
    }

    private func makeFailedSnapshot(entry: TranscriptEntry) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: .failed(message: "/Users/private/model.gguf"),
            transcript: [entry],
            modelStatus: nil,
            statusMessage: "/Users/private/model.gguf"
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

private enum ProjectionAdapterTestError: Error { case timedOut }

private actor ProjectionSessionControllerFake: LiveSessionController {
    private let initial: LiveSessionSnapshot
    private var continuation: AsyncStream<LiveSessionEvent>.Continuation?
    init(initial: LiveSessionSnapshot) { self.initial = initial }
    func start(inputDeviceID _: AudioInputID?) {}
    func stop() {}
    func currentSnapshot() -> LiveSessionSnapshot { initial }
    func events() -> AsyncStream<LiveSessionEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(.stateChanged(initial))
        }
    }
    func emit(_ event: LiveSessionEvent) { continuation?.yield(event) }
}

private actor ProjectionUpdateFake: RemoteProjectionUpdating {
    private var sessionIDs: [UUID] = []
    private var stateMessages: [String] = []
    private var projectedEntries: [RemoteProjectionEntryInput] = []
    func beginSession(id: UUID, message _: String) { sessionIDs.append(id) }
    func updateState(phase _: RemoteSessionPhase, message: String) { stateMessages.append(message) }
    func upsert(_ input: RemoteProjectionEntryInput) -> RemoteTranscriptEntry {
        projectedEntries.append(input)
        return RemoteTranscriptEntry(
            id: input.id,
            sequence: input.sequence,
            revision: UInt64(projectedEntries.count),
            sourceText: input.sourceText,
            targetText: input.targetText,
            createdAt: input.createdAt
        )
    }
    func heartbeat() {}
    func sessions() -> [UUID] { sessionIDs }
    func messages() -> [String] { stateMessages }
    func entries() -> [RemoteProjectionEntryInput] { projectedEntries }
}
