import Foundation

public protocol ModelLocationStore: Sendable {
    func location(for modelID: ModelID) async -> URL?
    func register(_ location: URL, for modelID: ModelID) async throws
    func removeLocation(for modelID: ModelID) async throws
}

public protocol ModelRuntimeReporting: Sendable {
    func status(for descriptor: ModelDescriptor) async -> ModelRuntimeStatus
    func setState(_ state: ModelRuntimeState, for descriptor: ModelDescriptor) async
    func events() async -> AsyncStream<ModelRuntimeStatus>
}
