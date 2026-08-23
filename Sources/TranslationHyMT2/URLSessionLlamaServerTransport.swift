import Foundation

actor URLSessionLlamaServerTransport: LlamaServerTransport {
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
        let request = try urlRequest(
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
        var urlRequest = try urlRequest(
            endpoint: endpoint,
            path: "/v1/chat/completions",
            method: "POST",
            timeout: timeout
        )
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(ChatRequest(request))
        let data = try await responseData(for: urlRequest)
        guard
            let content = try decoder.decode(ChatResponse.self, from: data)
                .choices.first?.message.content
        else {
            throw HyMT2Error.malformedResponse
        }
        return content
    }

    private func urlRequest(
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
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw HyMT2Error.malformedResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                throw HyMT2Error.transportFailure("HTTP \(http.statusCode)")
            }
            return data
        } catch let error as HyMT2Error {
            throw error
        } catch {
            throw HyMT2Error.transportFailure(error.localizedDescription)
        }
    }
}

private struct ChatRequest: Encodable {
    let messages: [Message]
    let temperature = 0.0
    let topP = 0.6
    let topK = 20
    let repetitionPenalty = 1.05
    let seed = 42
    let maximumTokens: Int
    let stop: [String]
    let stream = false

    init(_ request: LlamaCompletionRequest) {
        messages = [Message(role: "user", content: request.prompt)]
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

private struct Message: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }
}
