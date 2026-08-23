@testable import SessionManagement
import Testing

@Suite struct ModelPreparationRuntimeRecoveryTests {
    @Test func repeatedStartupPreparationIsIdempotent() async {
        let downloader = FakeModelDownloader()
        let asr = FakeMandarinASRProvider(text: "test")
        let translator = FakeHyTranslationProvider(shouldFail: false)
        let coordinator = makeCoordinator(
            downloader: downloader,
            asr: asr,
            translator: translator
        )

        await coordinator.prepareModels()
        await coordinator.prepareModels()

        #expect(await downloader.requestedDescriptors().count == 2)
        #expect(await asr.loadCount() == 1)
        #expect(await translator.loadCount() == 1)
    }

    @Test func unavailableHelperReloadsFromVerifiedLocationsWithoutRedownloading() async throws {
        let downloader = FakeModelDownloader()
        let asr = FakeMandarinASRProvider(text: "test")
        let translator = FakeHyTranslationProvider(shouldFail: false)
        let coordinator = makeCoordinator(
            downloader: downloader,
            asr: asr,
            translator: translator
        )
        try await coordinator.ensureReady()
        await translator.markRuntimeUnavailable()
        try await coordinator.ensureReady()
        #expect(await downloader.requestedDescriptors().count == 2)
        #expect(await asr.loadCount() == 2)
        #expect(await translator.loadCount() == 2)
        #expect(await coordinator.currentModelPreparation().isReady)
    }

    private func makeCoordinator(
        downloader: FakeModelDownloader,
        asr: FakeMandarinASRProvider,
        translator: FakeHyTranslationProvider
    ) -> InferenceModelPreparationCoordinator {
        InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: FakeModelRuntimeReporter(),
            asr: asr,
            translator: translator,
            models: ModelPreparationCoordinatorTests.models,
            retryDelays: [.zero]
        )
    }
}
