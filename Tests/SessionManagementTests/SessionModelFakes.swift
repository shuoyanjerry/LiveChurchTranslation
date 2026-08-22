import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI

actor FakeModelDownloader: ModelDownloadProvider {
    private let delay: Duration?
    private var descriptors: [ModelDescriptor] = []
    private var cancelledModelIDs: [ModelID] = []

    init(delay: Duration? = nil) {
        self.delay = delay
    }

    func ensureAvailable(_ descriptor: ModelDescriptor) async throws -> URL {
        descriptors.append(descriptor)
        if let delay { try await Task.sleep(for: delay) }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(descriptor.id.rawValue)
    }

    func cancelDownload(for modelID: ModelID) { cancelledModelIDs.append(modelID) }
    func requestedDescriptors() -> [ModelDescriptor] { descriptors }
    func cancelledDescriptors() -> [ModelID] { cancelledModelIDs }
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
