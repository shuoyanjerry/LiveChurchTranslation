import ASRAPI
import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI
import TranslationAPI

struct InferenceModelPreparationPipeline: Sendable {
    let modelDownloader: any ModelDownloadProvider
    let modelReporter: any ModelRuntimeReporting
    let asr: any ASRProvider
    let translator: any TranslationProvider
    let models: SessionModelDescriptors
    let scope: InferenceModelPreparationScope

    func runtimesAreReady() async -> Bool {
        let asrIsReady =
            await (asr as? any ModelRuntimeHealthChecking)?
            .isModelRuntimeReady() ?? true
        guard scope.requiresTranslation else { return asrIsReady }
        let translatorIsReady =
            await (translator as? any ModelRuntimeHealthChecking)?
            .isModelRuntimeReady() ?? true
        return asrIsReady && translatorIsReady
    }

    func run(
        reusing cachedLocations: InferenceModelLocations?,
        report: @escaping @Sendable (ModelRuntimeStatus) async -> Void
    ) async throws -> InferenceModelLocations {
        let events = await modelReporter.events()
        let observer = Task {
            for await status in events {
                guard !Task.isCancelled else { return }
                await report(status)
            }
        }
        defer { observer.cancel() }

        let locations: InferenceModelLocations
        if let cachedLocations {
            locations = cachedLocations
        } else {
            locations = try await downloadLocations()
        }
        try Task.checkCancellation()
        try await loadASR(at: locations.asr, report: report)
        if let translation = locations.translation {
            try await loadTranslation(at: translation, report: report)
        }
        return locations
    }

    private func downloadLocations() async throws -> InferenceModelLocations {
        guard scope.requiresTranslation else {
            return InferenceModelLocations(
                asr: try await modelDownloader.ensureAvailable(models.speechRecognition),
                translation: nil
            )
        }
        async let asr = modelDownloader.ensureAvailable(models.speechRecognition)
        async let translation = modelDownloader.ensureAvailable(models.translation)
        let locations = try await (asr, translation)
        return InferenceModelLocations(asr: locations.0, translation: locations.1)
    }

    private func loadASR(
        at location: URL,
        report: @escaping @Sendable (ModelRuntimeStatus) async -> Void
    ) async throws {
        let descriptor = models.speechRecognition
        await modelReporter.setState(.loading, for: descriptor)
        await report(ModelRuntimeStatus(descriptor: descriptor, state: .loading))
        do {
            try await asr.loadModel(at: location)
        } catch {
            await reportFailure(error, descriptor: descriptor)
            throw error
        }
        try Task.checkCancellation()
        await modelReporter.setState(.ready, for: descriptor)
    }

    private func loadTranslation(
        at location: URL,
        report: @escaping @Sendable (ModelRuntimeStatus) async -> Void
    ) async throws {
        let descriptor = models.translation
        await modelReporter.setState(.loading, for: descriptor)
        await report(ModelRuntimeStatus(descriptor: descriptor, state: .loading))
        do {
            try await translator.loadModel(at: location)
        } catch {
            await reportFailure(error, descriptor: descriptor)
            throw error
        }
        try Task.checkCancellation()
        await modelReporter.setState(.ready, for: descriptor)
    }

    private func reportFailure(_ error: any Error, descriptor: ModelDescriptor) async {
        await modelReporter.setState(
            .failed(message: error.localizedDescription),
            for: descriptor
        )
    }
}

struct InferenceModelLocations: Sendable {
    let asr: URL
    let translation: URL?
}
