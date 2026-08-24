import ASRAPI
import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI
import SessionManagementAPI
import TranslationAPI

public enum InferenceModelPreparationScope: Sendable {
    case speechRecognition
    case speechAndTranslation

    var requiresTranslation: Bool { self == .speechAndTranslation }

    var preparingMessage: String {
        switch self {
        case .speechRecognition: "正在准备本地语音识别模型…"
        case .speechAndTranslation: "正在准备本地语音与翻译模型…"
        }
    }

    var readyMessage: String {
        switch self {
        case .speechRecognition: "本地语音识别模型已就绪"
        case .speechAndTranslation: "本地语音与翻译模型已就绪"
        }
    }
}

public actor InferenceModelPreparationCoordinator: ModelPreparationController {
    let pipeline: InferenceModelPreparationPipeline
    let descriptors: [ModelDescriptor]
    let scope: InferenceModelPreparationScope
    let retryDelays: [Duration]
    var snapshot: ModelPreparationSnapshot
    var preparation: ActiveModelPreparation?
    var automaticPreparation: AutomaticModelPreparation?
    var isShutDown = false
    var progressByModel: [ModelID: Double] = [:]
    var cachedLocations: InferenceModelLocations?
    var waiters: [UUID: CheckedContinuation<Void, any Error>] = [:]
    var continuations: [UUID: AsyncStream<ModelPreparationSnapshot>.Continuation] = [:]

    public init(
        modelDownloader: any ModelDownloadProvider,
        modelReporter: any ModelRuntimeReporting,
        asr: any ASRProvider,
        translator: any TranslationProvider,
        models: SessionModelDescriptors,
        scope: InferenceModelPreparationScope = .speechAndTranslation,
        retryDelays: [Duration] = [.seconds(2), .seconds(5)]
    ) {
        pipeline = InferenceModelPreparationPipeline(
            modelDownloader: modelDownloader,
            modelReporter: modelReporter,
            asr: asr,
            translator: translator,
            models: models,
            scope: scope
        )
        descriptors =
            scope.requiresTranslation
            ? [models.speechRecognition, models.translation]
            : [models.speechRecognition]
        self.scope = scope
        snapshot = ModelPreparationSnapshot(
            phase: .idle,
            message: scope.preparingMessage
        )
        self.retryDelays = retryDelays
    }

    func startPreparationIfNeeded() {
        guard !isShutDown, preparation == nil else { return }
        let reusableLocations = snapshot.isReady ? cachedLocations : nil
        progressByModel = Dictionary(
            uniqueKeysWithValues: descriptors.map { ($0.id, 0) }
        )
        publish(
            ModelPreparationSnapshot(
                phase: .checking,
                message: "正在校验并载入随应用安装的本地模型…"
            )
        )
        let token = UUID()
        let pipeline = pipeline
        let coordinator = self
        let task = Task {
            let result: Result<InferenceModelLocations, any Error>
            do {
                result = .success(
                    try await pipeline.run(reusing: reusableLocations) { status in
                        await coordinator.receive(status, token: token)
                    })
            } catch {
                result = .failure(error)
            }
            await coordinator.finishPreparation(token: token, result: result)
        }
        preparation = ActiveModelPreparation(token: token, task: task)
    }
}

struct ActiveModelPreparation: Sendable {
    let token: UUID
    let task: Task<Void, Never>
}
