import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI
import SessionManagementAPI

extension InferenceModelPreparationCoordinator {
    func receive(_ status: ModelRuntimeStatus, token: UUID) {
        guard preparation?.token == token else { return }
        guard progressByModel[status.descriptor.id] != nil else { return }
        switch status.state {
        case .missing:
            break
        case .downloading(let progress):
            progressByModel[status.descriptor.id] = min(max(progress, 0), 1)
            publishDownload(message: "正在下载并校验本地模型")
        case .available:
            progressByModel[status.descriptor.id] = 1
            publishDownload(message: "正在校验本地模型")
        case .loading:
            publish(
                ModelPreparationSnapshot(
                    phase: .loading,
                    message: loadingMessage(for: status.descriptor)
                )
            )
        case .ready, .failed:
            break
        }
    }

    func finishPreparation(
        token: UUID,
        result: Result<InferenceModelLocations, any Error>
    ) {
        guard preparation?.token == token else { return }
        preparation = nil
        let pending = waiters.values
        waiters.removeAll()
        switch result {
        case .success(let locations):
            cachedLocations = locations
            publish(
                ModelPreparationSnapshot(
                    phase: .ready,
                    message: "本地语音与翻译模型已就绪"
                )
            )
            pending.forEach { $0.resume() }
        case .failure(let error):
            publish(
                ModelPreparationSnapshot(
                    phase: .failed,
                    message: Self.failureMessage(for: error)
                )
            )
            pending.forEach { $0.resume(throwing: error) }
        }
    }

    func cancelWaiter(_ id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiter.resume(throwing: CancellationError())
    }

    func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }

    func publish(_ newSnapshot: ModelPreparationSnapshot) {
        snapshot = newSnapshot
        continuations.values.forEach { $0.yield(newSnapshot) }
    }

    private func publishDownload(message: String) {
        let aggregate = aggregateProgress
        publish(
            ModelPreparationSnapshot(
                phase: .downloading(progress: aggregate),
                message: "\(message) · \(Int(aggregate * 100))%"
            )
        )
    }

    private var aggregateProgress: Double {
        let totalBytes = descriptors.reduce(Int64(0)) { $0 + max(1, $1.expectedBytes) }
        guard totalBytes > 0 else { return 0 }
        let completedBytes = descriptors.reduce(0.0) { partial, descriptor in
            partial + Double(max(1, descriptor.expectedBytes))
                * (progressByModel[descriptor.id] ?? 0)
        }
        return min(max(completedBytes / Double(totalBytes), 0), 1)
    }

    private func loadingMessage(for descriptor: ModelDescriptor) -> String {
        descriptor.id == descriptors.first?.id
            ? "正在载入语音识别模型…"
            : "正在载入中英翻译模型…"
    }

    private static func failureMessage(for error: any Error) -> String {
        if let presented = error as? any ModelPreparationUserFacingError {
            return presented.modelPreparationMessage
        }
        guard let downloadError = error as? ModelDownloadError else {
            return "本地模型无法载入。请重试；若问题持续，请重新启动应用。"
        }
        return switch downloadError {
        case .downloadFailed:
            "无法下载本地模型。请检查网络连接和磁盘空间后重试。"
        case .insufficientDiskSpace(let requiredBytes, let availableBytes):
            "磁盘空间不足。模型准备需要 \(formattedBytes(requiredBytes))，当前可用 "
                + "\(formattedBytes(availableBytes))。请释放空间后重试。"
        case .invalidArtifact:
            "模型文件校验失败，未使用不完整文件。请重试下载。"
        case .cancelled:
            "模型准备已中断，请重试。"
        }
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .file)
    }
}
