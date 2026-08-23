import Foundation
@testable import TranslationHyMT2

actor HyMT2NegationShadowQ4Transport: LlamaServerTransport {
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func checkHealth(
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws {
        let request = try request(
            endpoint: endpoint,
            path: "/health",
            method: "GET",
            timeout: timeout
        )
        _ = try await responseData(for: request)
    }

    func complete(
        _ request: LlamaCompletionRequest,
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws -> String {
        var urlRequest = try self.request(
            endpoint: endpoint,
            path: "/v1/chat/completions",
            method: "POST",
            timeout: timeout
        )
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(HyMT2NegationShadowChatRequest(request))
        let data = try await responseData(for: urlRequest)
        guard
            let content = try decoder.decode(HyMT2NegationShadowChatResponse.self, from: data)
                .choices.first?.message.content
        else {
            throw HyMT2Error.malformedResponse
        }
        return content
    }

    private func request(
        endpoint: LlamaServerEndpoint,
        path: String,
        method: String,
        timeout: TimeInterval
    ) throws -> URLRequest {
        var request = URLRequest(url: try endpoint.url(path: path))
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(endpoint.apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
            (200..<300).contains(http.statusCode)
        else {
            throw HyMT2Error.transportFailure("shadow HTTP failure")
        }
        return data
    }
}

private struct HyMT2NegationShadowChatRequest: Encodable {
    let messages: [HyMT2NegationShadowChatMessage]
    let temperature = HyMT2NegationShadowQ4Settings.temperature
    let topP = HyMT2NegationShadowQ4Settings.topP
    let topK = HyMT2NegationShadowQ4Settings.topK
    let repetitionPenalty = HyMT2NegationShadowQ4Settings.repetitionPenalty
    let seed = HyMT2NegationShadowQ4Settings.seed
    let maximumTokens: Int
    let stop: [String]
    let stream = false

    init(_ request: LlamaCompletionRequest) {
        messages = [.init(role: "user", content: request.prompt)]
        maximumTokens = request.maximumTokens
        stop = request.stopSequences
    }

    enum CodingKeys: String, CodingKey {
        case messages, temperature, seed, stop, stream
        case topP = "top_p"
        case topK = "top_k"
        case repetitionPenalty = "repeat_penalty"
        case maximumTokens = "max_tokens"
    }
}

private struct HyMT2NegationShadowChatMessage: Codable {
    let role: String
    let content: String
}

private struct HyMT2NegationShadowChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: HyMT2NegationShadowChatMessage
    }
}
