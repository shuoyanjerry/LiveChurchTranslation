import Foundation

struct LlamaCompletionRequest: Equatable, Sendable {
    let prompt: String
    let maximumTokens: Int
}

protocol LlamaServerTransport: Sendable {
    func checkHealth(
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws

    func complete(
        _ request: LlamaCompletionRequest,
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws -> String
}
