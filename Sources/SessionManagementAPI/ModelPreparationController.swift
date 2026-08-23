import Foundation

public enum ModelPreparationPhase: Equatable, Sendable {
    case idle
    case checking
    case downloading(progress: Double)
    case loading
    case retrying(attempt: Int)
    case ready
    case failed
}

public struct ModelPreparationSnapshot: Equatable, Sendable {
    public let phase: ModelPreparationPhase
    public let message: String

    public init(phase: ModelPreparationPhase, message: String) {
        self.phase = phase
        self.message = message
    }

    public var isReady: Bool { phase == .ready }
    public var canRetry: Bool { phase == .failed }
}

public protocol ModelPreparationController: Sendable {
    func prepareModels() async
    func retryModelPreparation() async
    func currentModelPreparation() async -> ModelPreparationSnapshot
    func modelPreparationEvents() async -> AsyncStream<ModelPreparationSnapshot>
}
