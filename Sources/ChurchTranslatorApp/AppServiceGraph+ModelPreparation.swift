import ASRQwen3
import ModelDownloadAPI
import ModelRuntimeCore
import SessionManagement
import TranslationHyMT2

extension AppServiceGraph {
    static func makeModelPreparations(
        downloader: any ModelDownloadProvider,
        reporter: ModelRuntimeReporter,
        asr: Qwen3ASRProvider,
        translator: HyMT2TranslationProvider,
        models: SessionModelDescriptors
    ) -> (InferenceModelPreparationCoordinator, InferenceModelPreparationCoordinator) {
        let live = InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: reporter,
            asr: asr,
            translator: translator,
            models: models
        )
        let transcription = InferenceModelPreparationCoordinator(
            modelDownloader: downloader,
            modelReporter: reporter,
            asr: asr,
            translator: translator,
            models: models,
            scope: .speechRecognition
        )
        return (live, transcription)
    }
}
