import Foundation

struct LlamaServerLaunchRequest: Equatable, Sendable {
    let modelURL: URL
    let endpoint: LlamaServerEndpoint
    let contextSize: Int
    let threadCount: Int
    let gpuLayerCount: Int
}

protocol LlamaServerControlling: Sendable {
    func launch(_ request: LlamaServerLaunchRequest) async throws
    func isRunning() async -> Bool
    func stop() async
}
