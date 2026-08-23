import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite struct ModelPreparationCoordinatorTests {}

extension ModelPreparationCoordinatorTests {
    @Test func concurrentCallersShareOnePreparationAttempt() async throws {
        let downloader = FakeModelDownloader(delay: .milliseconds(50))
        let asr = FakeMandarinASRProvider(text: "test")
        let translator = FakeHyTranslationProvider(shouldFail: false)
        let coordinator = makeCoordinator(
            downloader: downloader,
            asr: asr,
            translator: translator
        )

        async let first: Void = coordinator.ensureReady()
        async let second: Void = coordinator.ensureReady()
        _ = try await (first, second)

        #expect(await downloader.requestedDescriptors().count == 2)
        #expect(await asr.loadCount() == 1)
        #expect(await translator.loadCount() == 1)
        #expect(await coordinator.currentModelPreparation().isReady)
    }

    @Test func automaticFailureCanBeRetriedWithoutRecreatingTheCoordinator() async {
        let downloader = FakeModelDownloader(failuresBeforeSuccess: .max)
        let asr = FakeMandarinASRProvider(text: "test")
        let translator = FakeHyTranslationProvider(shouldFail: false)
        let coordinator = makeCoordinator(
            downloader: downloader,
            asr: asr,
            translator: translator,
            retryDelays: [.zero, .zero]
        )

        await coordinator.prepareModels()
        #expect(await coordinator.currentModelPreparation().canRetry)

        await downloader.allowDownloads()
        await coordinator.retryModelPreparation()

        #expect(await coordinator.currentModelPreparation().isReady)
        #expect(await asr.loadCount() == 1)
        #expect(await translator.loadCount() == 1)
    }

    @Test func cancellingOneWaiterDoesNotCancelSharedPreparation() async throws {
        let downloader = FakeModelDownloader(delay: .milliseconds(100))
        let coordinator = makeCoordinator(
            downloader: downloader,
            asr: FakeMandarinASRProvider(text: "test"),
            translator: FakeHyTranslationProvider(shouldFail: false)
        )
        let cancelledWaiter = Task { try await coordinator.ensureReady() }
        try await waitUntil { !(await downloader.requestedDescriptors()).isEmpty }

        cancelledWaiter.cancel()
        do {
            try await cancelledWaiter.value
            Issue.record("Expected the session waiter to observe cancellation")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected cancellation error: \(error)")
        }

        try await coordinator.ensureReady()
        #expect(await downloader.requestedDescriptors().count == 2)
        #expect(await coordinator.currentModelPreparation().isReady)
    }

    @Test func runtimeLoadFailureReplacesTransientLoadingStatus() async {
        let reporter = FakeModelRuntimeReporter()
        let coordinator = InferenceModelPreparationCoordinator(
            modelDownloader: FakeModelDownloader(),
            modelReporter: reporter,
            asr: FakeMandarinASRProvider(text: "test", loadFails: true),
            translator: FakeHyTranslationProvider(shouldFail: false),
            models: Self.models,
            retryDelays: []
        )

        do {
            try await coordinator.ensureReady()
            Issue.record("Expected ASR model loading to fail")
        } catch {
            #expect(error is SessionPipelineFakeError)
        }

        let status = await reporter.status(for: Self.models.speechRecognition)
        guard case .failed = status.state else {
            Issue.record("Expected the reporter to leave loading and publish failure")
            return
        }
        #expect(await coordinator.currentModelPreparation().canRetry)
    }

    @Test func insufficientDiskFailureShowsRequiredAndAvailableCapacity() async {
        let requiredBytes: Int64 = 3_000_000_000
        let availableBytes: Int64 = 2_000_000_000
        let coordinator = InferenceModelPreparationCoordinator(
            modelDownloader: InsufficientDiskModelDownloader(
                requiredBytes: requiredBytes,
                availableBytes: availableBytes
            ),
            modelReporter: FakeModelRuntimeReporter(),
            asr: FakeMandarinASRProvider(text: "test"),
            translator: FakeHyTranslationProvider(shouldFail: false),
            models: Self.models,
            retryDelays: []
        )

        await coordinator.prepareModels()

        let snapshot = await coordinator.currentModelPreparation()
        let required = ByteCountFormatter.string(
            fromByteCount: requiredBytes,
            countStyle: .file
        )
        let available = ByteCountFormatter.string(
            fromByteCount: availableBytes,
            countStyle: .file
        )
        #expect(snapshot.canRetry)
        #expect(snapshot.message.contains("磁盘空间不足"))
        #expect(snapshot.message.contains(required))
        #expect(snapshot.message.contains(available))
    }

    private func makeCoordinator(
        downloader: FakeModelDownloader,
        asr: FakeMandarinASRProvider,
        translator: FakeHyTranslationProvider,
        retryDelays: [Duration] = [.zero]
    ) -> InferenceModelPreparationCoordinator {
        InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: FakeModelRuntimeReporter(),
            asr: asr,
            translator: translator,
            models: Self.models,
            retryDelays: retryDelays
        )
    }

    static let models = SessionModelDescriptors(
        speechRecognition: descriptor(id: "asr", name: "ASR", bytes: 3),
        translation: descriptor(id: "translation", name: "Translation", bytes: 7)
    )

    private static func descriptor(id: String, name: String, bytes: Int64) -> ModelDescriptor {
        ModelDescriptor(
            id: ModelID(rawValue: id),
            displayName: name,
            version: "test",
            expectedBytes: bytes,
            sha256: nil,
            license: "test"
        )
    }
}
