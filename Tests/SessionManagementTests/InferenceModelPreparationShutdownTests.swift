@testable import SessionManagement
import Testing

extension ModelPreparationCoordinatorTests {
    @Test func shutdownCancelsAndJoinsSharedPreparationPermanently() async throws {
        let downloader = FakeModelDownloader(delay: .seconds(30))
        let asr = FakeMandarinASRProvider(text: "test")
        let translator = FakeHyTranslationProvider(shouldFail: false)
        let coordinator = shutdownTestCoordinator(
            downloader: downloader,
            asr: asr,
            translator: translator
        )
        let waiter = Task { try await coordinator.ensureReady() }
        try await waitUntil { (await downloader.requestedDescriptors()).count == 2 }

        await coordinator.shutdownModelPreparation()
        await expectPreparationCancellation(waiter)
        #expect(await asr.loadCount() == 0)
        #expect(await translator.loadCount() == 0)
        #expect(
            Set(await downloader.cancelledDescriptors())
                == Set([Self.models.speechRecognition.id, Self.models.translation.id])
        )
        let requestCount = await downloader.requestedDescriptors().count

        await coordinator.prepareModels()
        await coordinator.retryModelPreparation()
        do {
            try await coordinator.ensureReady()
            Issue.record("Expected a shut-down coordinator to remain terminal")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected terminal error: \(error)")
        }
        #expect(await downloader.requestedDescriptors().count == requestCount)
        #expect(await asr.loadCount() == 0)
        #expect(await translator.loadCount() == 0)
    }

    @Test func immediateShutdownCannotStartADeferredDownload() async {
        for _ in 0..<50 {
            let downloader = FakeModelDownloader(delay: .seconds(30))
            let asr = FakeMandarinASRProvider(text: "test")
            let translator = FakeHyTranslationProvider(shouldFail: false)
            let coordinator = shutdownTestCoordinator(
                downloader: downloader,
                asr: asr,
                translator: translator
            )
            let waiter = Task { try await coordinator.ensureReady() }

            await coordinator.shutdownModelPreparation()
            _ = await waiter.result

            #expect(await asr.loadCount() == 0)
            #expect(await translator.loadCount() == 0)
            #expect(
                Set(await downloader.cancelledDescriptors())
                    == Set([Self.models.speechRecognition.id, Self.models.translation.id])
            )
        }
    }

    private func shutdownTestCoordinator(
        downloader: FakeModelDownloader,
        asr: FakeMandarinASRProvider,
        translator: FakeHyTranslationProvider
    ) -> InferenceModelPreparationCoordinator {
        InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: FakeModelRuntimeReporter(),
            asr: asr,
            translator: translator,
            models: Self.models,
            retryDelays: [.zero]
        )
    }

    private func expectPreparationCancellation(
        _ waiter: Task<Void, any Error>
    ) async {
        do {
            try await waiter.value
            Issue.record("Expected shutdown to cancel the preparation waiter")
        } catch is CancellationError {
        } catch {
            Issue.record("Unexpected shutdown error: \(error)")
        }
    }
}
