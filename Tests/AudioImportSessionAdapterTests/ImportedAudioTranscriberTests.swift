import AudioCaptureAPI
import AudioImportSessionAdapter
import Foundation
import SessionManagementAPI
import SettingsAPI
import Testing

@Suite @MainActor struct ImportedAudioTranscriberTests {
    @Test func cancellationBeforeEventsReturnNeverStartsImport() async throws {
        let controller = ImportedAudioControllerStub(holdEvents: true)
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.eventsCallCount() == 1 }

        await transcriber.cancelImport()
        await controller.releaseEvents()
        try await importTask.value

        #expect(await controller.startCallCount() == 0)
        #expect(await controller.stopCallCount() >= 1)
    }

    @Test func cancellationWhileStartIsPendingStopsWithoutAnError() async throws {
        let controller = ImportedAudioControllerStub(holdStart: true)
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.startCallCount() == 1 }

        await transcriber.cancelImport()
        await controller.releaseStart()
        try await importTask.value

        #expect(await controller.stopCallCount() >= 1)
    }

    @Test func cancellationAfterStartReturnsStopsWithoutAnError() async throws {
        let controller = ImportedAudioControllerStub()
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.startCallCount() == 1 }

        await transcriber.cancelImport()
        try await importTask.value

        #expect(await controller.stopCallCount() >= 1)
    }

    private func makeTranscriber(
        _ controller: ImportedAudioControllerStub
    ) -> ImportedAudioTranscriber {
        ImportedAudioTranscriber(
            inputDeviceID: AudioInputID(rawValue: "import-test")
        ) { _, _ in controller }
    }

    private func startImport(
        _ transcriber: ImportedAudioTranscriber
    ) -> Task<Void, any Error> {
        Task {
            try await transcriber.importAudio(
                from: URL(fileURLWithPath: "/tmp/import.wav"),
                mode: .mandarinToEnglish
            )
        }
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw ImportedAudioTestError.timedOut
    }
}

private enum ImportedAudioTestError: Error {
    case timedOut
}

private actor ImportedAudioControllerStub: LiveSessionController {
    private let holdEvents: Bool
    private let holdStart: Bool
    private var eventCalls = 0
    private var startCalls = 0
    private var stopCalls = 0
    private var eventWaiters: [CheckedContinuation<Void, Never>] = []
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var streamContinuation: AsyncStream<LiveSessionEvent>.Continuation?

    init(holdEvents: Bool = false, holdStart: Bool = false) {
        self.holdEvents = holdEvents
        self.holdStart = holdStart
    }

    func events() async -> AsyncStream<LiveSessionEvent> {
        eventCalls += 1
        if holdEvents {
            await withCheckedContinuation { eventWaiters.append($0) }
        }
        let (stream, continuation) = AsyncStream.makeStream(of: LiveSessionEvent.self)
        streamContinuation = continuation
        return stream
    }

    func start(inputDeviceID _: AudioInputID?) async {
        startCalls += 1
        if holdStart {
            await withCheckedContinuation { startWaiters.append($0) }
        }
    }

    func stop() {
        stopCalls += 1
        streamContinuation?.finish()
    }

    func currentSnapshot() -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: .idle,
            transcript: [],
            modelStatus: nil,
            statusMessage: ""
        )
    }

    func releaseEvents() {
        let waiters = eventWaiters
        eventWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func releaseStart() {
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func eventsCallCount() -> Int { eventCalls }
    func startCallCount() -> Int { startCalls }
    func stopCallCount() -> Int { stopCalls }
}
