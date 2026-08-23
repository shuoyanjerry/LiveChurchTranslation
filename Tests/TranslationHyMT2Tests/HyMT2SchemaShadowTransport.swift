import Foundation
@testable import TranslationHyMT2

actor HyMT2SchemaShadowTransport: LlamaServerTransport {
    private let session: URLSession
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
        let data = try HyMT2SchemaShadowWire.requestData(
            prompt: request.prompt,
            maximumTokens: request.maximumTokens,
            stop: request.stopSequences,
            schema: nil,
            nonceAbsentFromPrompt: nil
        )
        return try await completion(data, endpoint: endpoint, timeout: timeout)
    }

    func completeSchema(
        _ request: HyMT2SchemaShadowSchemaRequest,
        at endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws -> String {
        guard !request.prompt.contains(request.nonce) else {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        let data = try HyMT2SchemaShadowWire.requestData(
            prompt: request.prompt,
            maximumTokens: request.maximumTokens,
            stop: request.stop,
            schema: request.schema,
            nonceAbsentFromPrompt: request.nonce
        )
        return try await completion(data, endpoint: endpoint, timeout: timeout)
    }

    private func completion(
        _ body: Data,
        endpoint: LlamaServerEndpoint,
        timeout: TimeInterval
    ) async throws -> String {
        var urlRequest = try request(
            endpoint: endpoint,
            path: "/v1/chat/completions",
            method: "POST",
            timeout: timeout
        )
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body
        let response = try await responseData(for: urlRequest)
        guard
            let content = try decoder.decode(HyMT2SchemaShadowChatResponse.self, from: response)
                .choices.first?.message.content
        else {
            throw HyMT2SchemaShadowFailureCode.transport
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
            throw HyMT2SchemaShadowFailureCode.transport
        }
        return data
    }
}

enum HyMT2SchemaShadowWire {
    static func requestData(
        prompt: String,
        maximumTokens: Int,
        stop: [String],
        schema: HyMT2SchemaShadowSchema?,
        nonceAbsentFromPrompt: String?
    ) throws -> Data {
        if let nonceAbsentFromPrompt, prompt.contains(nonceAbsentFromPrompt) {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        let value = HyMT2SchemaShadowChatRequest(
            prompt: prompt,
            maximumTokens: maximumTokens,
            stop: stop,
            schema: schema
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
