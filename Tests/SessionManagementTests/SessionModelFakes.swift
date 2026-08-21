import Foundation
import ModelDownloadAPI
import ModelRuntimeAPI

actor FakeModelDownloader: ModelDownloadProvider {
    private var descriptors: [ModelDescriptor] = []

    func ensureAvailable(_ descriptor: ModelDescriptor) -> URL {
        descriptors.append(descriptor)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(descriptor.id.rawValue)
    }

    func cancelDownload(for _: ModelID) {}
    func requestedDescriptors() -> [ModelDescriptor] { descriptors }
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
