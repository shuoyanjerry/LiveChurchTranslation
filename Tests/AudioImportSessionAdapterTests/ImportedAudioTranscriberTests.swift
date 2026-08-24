import AudioCaptureAPI
import AudioImportAPI
import AudioImportSessionAdapter
import Foundation
import SessionManagementAPI
import SettingsAPI
import Testing

@Suite @MainActor struct ImportedAudioTranscriberTests {
    @Test func rejectedSourceNeverCreatesOrStartsASession() async {
        let controller = ImportedAudioControllerStub()
        var factoryCallCount = 0
        let transcriber = ImportedAudioTranscriber(
            inputDeviceID: AudioInputID(rawValue: "import-test"),
            validateSource: { _ in throw ImportedAudioTestError.rejectedSource },
            makeController: { _, _, _ in
                factoryCallCount += 1
                return controller
            }
        )

        await #expect(throws: ImportedAudioTestError.rejectedSource) {
            try await transcriber.importAudio(
                from: URL(fileURLWithPath: "/tmp/video-without-audio.mp4"),
                mode: .englishToSimplifiedChinese
            )
        }

        #expect(factoryCallCount == 0)
        #expect(await controller.eventsCallCount() == 0)
        #expect(await controller.startCallCount() == 0)
    }

    @Test func cancellationBeforeEventsReturnNeverStartsAndReportsCancellation() async throws {
        let controller = ImportedAudioControllerStub(holdEvents: true)
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.eventsCallCount() == 1 }

        await transcriber.cancelImport()
        await controller.releaseEvents()
        await #expect(throws: AudioImportError.cancelled) {
            try await importTask.value
        }

        #expect(await controller.startCallCount() == 0)
        #expect(await controller.stopCallCount() >= 1)
    }

    @Test func cancellationWhileStartIsPendingStopsAndReportsCancellation() async throws {
        let controller = ImportedAudioControllerStub(holdStart: true)
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.startCallCount() == 1 }

        await transcriber.cancelImport()
        await controller.releaseStart()
        await #expect(throws: AudioImportError.cancelled) {
            try await importTask.value
        }

        #expect(await controller.stopCallCount() >= 1)
    }

    @Test func cancellationAfterStartReturnsStopsAndReportsCancellation() async throws {
        let controller = ImportedAudioControllerStub()
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.startCallCount() == 1 }

        await transcriber.cancelImport()
        await #expect(throws: AudioImportError.cancelled) {
            try await importTask.value
        }

        #expect(await controller.stopCallCount() >= 1)
    }

    @Test func cancellingCallerTaskPropagatesToActiveImport() async throws {
        let controller = ImportedAudioControllerStub()
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.startCallCount() == 1 }

        importTask.cancel()
        await #expect(throws: AudioImportError.cancelled) {
            try await importTask.value
        }

        #expect(await controller.stopCallCount() >= 1)
    }

    @Test func shutdownJoinsTheActiveImportAndPermanentlyRejectsNewImports() async throws {
        let controller = ImportedAudioControllerStub()
        let transcriber = makeTranscriber(controller)
        let importTask = startImport(transcriber)
        try await waitUntil { await controller.startCallCount() == 1 }

        await transcriber.shutdown()
        await #expect(throws: AudioImportError.cancelled) {
            try await importTask.value
        }
        await #expect(throws: AudioImportError.cancelled) {
            try await transcriber.importAudio(
                from: URL(fileURLWithPath: "/tmp/second-import.wav"),
                mode: .englishToSimplifiedChinese
            )
        }

        #expect(await controller.stopCallCount() >= 1)
        #expect(await controller.startCallCount() == 1)
    }

    private func makeTranscriber(
        _ controller: ImportedAudioControllerStub
    ) -> ImportedAudioTranscriber {
        ImportedAudioTranscriber(
            inputDeviceID: AudioInputID(rawValue: "import-test")
        ) { _, _, _ in controller }
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

enum ImportedAudioTestError: Error {
    case rejectedSource
    case timedOut
}
