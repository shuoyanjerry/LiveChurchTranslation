@testable import SessionManagement
import Testing

@Suite struct SpeechRecognitionModelPreparationTests {
    @Test func speechOnlyShutdownCancelsOnlyTheRecognitionDownload() async {
        let downloader = FakeModelDownloader(delay: .seconds(30))
        let coordinator = InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: FakeModelRuntimeReporter(),
            asr: FakeMandarinASRProvider(text: "test"),
            translator: FakeHyTranslationProvider(shouldFail: false),
            models: ModelPreparationCoordinatorTests.models,
            scope: .speechRecognition,
            retryDelays: []
        )
        let waiter = Task { try await coordinator.ensureReady() }

        await coordinator.shutdownModelPreparation()
        _ = await waiter.result

        #expect(
            await downloader.cancelledDescriptors()
                == [ModelPreparationCoordinatorTests.models.speechRecognition.id]
        )
    }

    @Test func speechOnlyScopeNeverLoadsOrChecksTranslationRuntime() async throws {
        let downloader = FakeModelDownloader()
        let asr = FakeMandarinASRProvider(text: "test")
        let translator = FakeHyTranslationProvider(shouldFail: true)
        let coordinator = InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: FakeModelRuntimeReporter(),
            asr: asr,
            translator: translator,
            models: ModelPreparationCoordinatorTests.models,
            scope: .speechRecognition,
            retryDelays: []
        )

        try await coordinator.ensureReady()

        #expect(
            await downloader.requestedDescriptors()
                == [ModelPreparationCoordinatorTests.models.speechRecognition]
        )
        #expect(await asr.loadCount() == 1)
        #expect(await translator.loadCount() == 0)
        #expect(await translator.runtimeCheckCount() == 0)
        #expect((await translator.receivedRequests()).isEmpty)
        #expect(await coordinator.currentModelPreparation().isReady)
    }
}
