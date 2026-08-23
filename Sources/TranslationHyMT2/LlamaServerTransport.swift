import Foundation

struct LlamaCompletionRequest: Equatable, Sendable {
    let prompt: String
    let maximumTokens: Int
    let stopSequences: [String]

    init(
        prompt: String,
        maximumTokens: Int,
        stopSequences: [String] = []
    ) {
        self.prompt = prompt
        self.maximumTokens = maximumTokens
        self.stopSequences = stopSequences
    }
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
