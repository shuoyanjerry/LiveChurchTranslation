struct HyMT2SchemaShadowChatRequest: Encodable {
    let messages: [HyMT2SchemaShadowChatMessage]
    let temperature = HyMT2NegationShadowQ4Settings.temperature
    let topP = HyMT2NegationShadowQ4Settings.topP
    let topK = HyMT2NegationShadowQ4Settings.topK
    let repetitionPenalty = HyMT2NegationShadowQ4Settings.repetitionPenalty
    let seed = HyMT2NegationShadowQ4Settings.seed
    let maximumTokens: Int
    let stop: [String]
    let stream = false
    let responseFormat: HyMT2SchemaShadowResponseFormat?

    init(
        prompt: String,
        maximumTokens: Int,
        stop: [String],
        schema: HyMT2SchemaShadowSchema?
    ) {
        messages = [.init(role: "user", content: prompt)]
        self.maximumTokens = maximumTokens
        self.stop = stop
        responseFormat = schema.map(HyMT2SchemaShadowResponseFormat.init)
    }

    enum CodingKeys: String, CodingKey {
        case messages, temperature, seed, stop, stream
        case topP = "top_p"
        case topK = "top_k"
        case repetitionPenalty = "repeat_penalty"
        case maximumTokens = "max_tokens"
        case responseFormat = "response_format"
    }
}

struct HyMT2SchemaShadowResponseFormat: Encodable {
    let type = "json_schema"
    let jsonSchema: Definition

    init(schema: HyMT2SchemaShadowSchema) {
        jsonSchema = Definition(schema: schema)
    }

    struct Definition: Encodable {
        let name = "hymt2_schema_shadow"
        let strict = true
        let schema: HyMT2SchemaShadowSchema
    }

    enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }
}

struct HyMT2SchemaShadowChatMessage: Codable {
    let role: String
    let content: String
}

struct HyMT2SchemaShadowChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: HyMT2SchemaShadowChatMessage
    }
}
