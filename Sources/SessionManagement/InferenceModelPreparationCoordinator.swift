import ASRAPI
import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI
import SessionManagementAPI
import TranslationAPI

public actor InferenceModelPreparationCoordinator: ModelPreparationController {
    let pipeline: InferenceModelPreparationPipeline
    let descriptors: [ModelDescriptor]
    private let retryDelays: [Duration]
    var snapshot = ModelPreparationSnapshot(
        phase: .idle,
        message: "正在准备本地语音与翻译模型…"
    )
    var preparation: ActiveModelPreparation?
    private var automaticPreparation: AutomaticModelPreparation?
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
        retryDelays: [Duration] = [.seconds(2), .seconds(5)]
    ) {
        pipeline = InferenceModelPreparationPipeline(
            modelDownloader: modelDownloader,
            modelReporter: modelReporter,
            asr: asr,
            translator: translator,
            models: models
        )
        descriptors = [models.speechRecognition, models.translation]
        self.retryDelays = retryDelays
    }

    public func prepareModels() async {
        let active = automaticPreparation ?? startAutomaticPreparation()
        await active.task.value
        clearAutomaticPreparation(matching: active.token)
    }

    public func retryModelPreparation() async {
        if let active = automaticPreparation {
            await active.task.value
            clearAutomaticPreparation(matching: active.token)
        }
        guard !snapshot.isReady else { return }
        let active = startAutomaticPreparation()
        await active.task.value
        clearAutomaticPreparation(matching: active.token)
    }

    private func startAutomaticPreparation() -> AutomaticModelPreparation {
        let token = UUID()
        let coordinator = self
        let task = Task<Void, Never> {
            await coordinator.performAutomaticPreparation()
        }
        let active = AutomaticModelPreparation(token: token, task: task)
        automaticPreparation = active
        return active
    }

    private func performAutomaticPreparation() async {
        for attemptIndex in 0...retryDelays.count {
            do {
                try await ensureReady()
                return
            } catch is CancellationError {
                return
            } catch {
                guard attemptIndex < retryDelays.count else { return }
                let nextAttempt = attemptIndex + 2
                publish(
                    ModelPreparationSnapshot(
                        phase: .retrying(attempt: nextAttempt),
                        message: "模型准备暂时中断，即将自动重试（\(nextAttempt)/\(retryDelays.count + 1)）…"
                    )
                )
                try? await Task.sleep(for: retryDelays[attemptIndex])
            }
        }
    }

    private func clearAutomaticPreparation(matching token: UUID) {
        guard automaticPreparation?.token == token else { return }
        automaticPreparation = nil
    }

    func startPreparationIfNeeded() {
        guard preparation == nil else { return }
        let reusableLocations = snapshot.isReady ? cachedLocations : nil
        progressByModel = Dictionary(
            uniqueKeysWithValues: descriptors.map { ($0.id, 0) }
        )
        publish(
            ModelPreparationSnapshot(
                phase: .checking,
                message: "正在检查本地模型并自动补齐所需文件…"
            )
        )
        let token = UUID()
        let pipeline = pipeline
        let coordinator = self
        Task {
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
        preparation = ActiveModelPreparation(token: token)
    }
}

struct ActiveModelPreparation: Sendable {
    let token: UUID
}

private struct AutomaticModelPreparation: Sendable {
    let token: UUID
    let task: Task<Void, Never>
}
