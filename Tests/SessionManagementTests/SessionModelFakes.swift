import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI

actor FakeModelDownloader: ModelDownloadProvider {
    private let delay: Duration?
    private var remainingFailures: Int
    private var descriptors: [ModelDescriptor] = []
    private var cancelledModelIDs: [ModelID] = []

    init(delay: Duration? = nil, failuresBeforeSuccess: Int = 0) {
        self.delay = delay
        remainingFailures = failuresBeforeSuccess
    }

    func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL {
        descriptors.append(descriptor)
        if let delay { try await Task.sleep(for: delay) }
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw ModelDownloadError.downloadFailed("Temporary test failure")
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(descriptor.id.rawValue)
    }

    func cancelDownload(for modelID: ModelID) { cancelledModelIDs.append(modelID) }
    func allowDownloads() { remainingFailures = 0 }
    func requestedDescriptors() -> [ModelDescriptor] { descriptors }
    func cancelledDescriptors() -> [ModelID] { cancelledModelIDs }
}

struct InsufficientDiskModelDownloader: ModelDownloadProvider {
    let requiredBytes: Int64
    let availableBytes: Int64

    func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL {
        throw ModelDownloadError.insufficientDiskSpace(
            requiredBytes: requiredBytes,
            availableBytes: availableBytes
        )
    }

    func cancelDownload(for modelID: ModelID) async {}
}

actor FakeModelRuntimeReporter: ModelRuntimeReporting {
    private var statuses: [ModelID: ModelRuntimeStatus] = [:]

    func status(for descriptor: ModelDescriptor) -> ModelRuntimeStatus {
        statuses[descriptor.id]
            ?? ModelRuntimeStatus(descriptor: descriptor, state: .missing)
    }

    func setState(_ state: ModelRuntimeState, for descriptor: ModelDescriptor) {
        statuses[descriptor.id] = ModelRuntimeStatus(
            descriptor: descriptor,
            state: state
        )
    }

    func events() -> AsyncStream<ModelRuntimeStatus> {
        AsyncStream { $0.finish() }
    }
}
