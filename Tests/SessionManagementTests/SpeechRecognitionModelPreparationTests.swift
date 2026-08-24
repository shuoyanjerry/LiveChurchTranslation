@testable import SessionManagement
import Testing

@Suite struct SpeechRecognitionModelPreparationTests {
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
