import Foundation

struct HyMT2SchemaShadowProbeResult: Codable, Equatable, Sendable {
    let status: HyMT2SchemaShadowStatus
    let failureCode: HyMT2SchemaShadowFailureCode?
    let latencyMilliseconds: Double
    let outputSHA256: String?
    let schemaSHA256: String
}

struct HyMT2SchemaShadowResult: Codable, Equatable, Sendable {
    let fixtureID: String
    let family: HyMT2SchemaShadowFamily
    let variant: HyMT2SchemaShadowVariant
    let occurrenceCount: Int
    let status: HyMT2SchemaShadowStatus
    let failureCode: HyMT2SchemaShadowFailureCode?
    let latencyMilliseconds: Double
    let outputSHA256: String?
    let schemaSHA256: String?
}

struct HyMT2SchemaShadowReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let seed: Int
    let temperature: Double
    let topP: Double
    let topK: Int
    let repetitionPenalty: Double
    let threadCount: Int
    let contextSize: Int
    let maximumTokens: Int
    let modelSHA256: String
    let helperSHA256: String
    let configurationSHA256: String
    let backgroundLoad: String
    let latencyControlled: Bool
    let probe: HyMT2SchemaShadowProbeResult
    let results: [HyMT2SchemaShadowResult]

    init(
        environment: HyMT2NegationShadowQ4Environment,
        configurationSHA256: String,
        probe: HyMT2SchemaShadowProbeResult,
        results: [HyMT2SchemaShadowResult]
    ) {
        let settings = HyMT2NegationShadowQ4Settings.self
        schemaVersion = 1
        seed = settings.seed
        temperature = settings.temperature
        topP = settings.topP
        topK = settings.topK
        repetitionPenalty = settings.repetitionPenalty
        threadCount = settings.threadCount
        contextSize = settings.contextSize
        maximumTokens = settings.maximumTokens
        modelSHA256 = environment.modelSHA256
        helperSHA256 = environment.helperSHA256
        self.configurationSHA256 = configurationSHA256
        backgroundLoad = "idle-sibling-q8-resident"
        latencyControlled = false
        self.probe = probe
        self.results = results
    }
}
