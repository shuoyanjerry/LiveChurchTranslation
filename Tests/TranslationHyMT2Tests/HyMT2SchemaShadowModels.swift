import Foundation
import TranslationAPI

enum HyMT2SchemaShadowFamily: String, Codable, Hashable, Sendable {
    case negation
    case pronoun
}

enum HyMT2SchemaShadowVariant: String, CaseIterable, Codable, Hashable, Sendable {
    case current
    case schema
}

enum HyMT2SchemaShadowFailureCode: String, Codable, Error, Sendable {
    case bindingKeys = "schema.binding.keys"
    case bindingShape = "schema.binding.shape"
    case bindingSurface = "schema.binding.surface"
    case currentProtocol = "current.protocol"
    case envelopeJSON = "schema.envelope.json"
    case envelopeKeys = "schema.envelope.keys"
    case nonceMismatch = "schema.nonce.mismatch"
    case placeholderDuplicate = "schema.placeholder.duplicate"
    case placeholderBoundary = "schema.placeholder.boundary"
    case placeholderMissing = "schema.placeholder.missing"
    case placeholderResidual = "schema.placeholder.residual"
    case placeholderUnknown = "schema.placeholder.unknown"
    case probeFailed = "schema.probe.failed"
    case protocolResidual = "schema.protocol.residual"
    case runtimeOutput = "runtime.output"
    case schemaInvalid = "schema.definition.invalid"
    case semanticAnchor = "schema.semantic.anchor"
    case semanticOccurrence = "schema.semantic.occurrence"
    case semanticSurface = "schema.semantic.surface"
    case targetEmpty = "schema.target.empty"
    case transport = "schema.transport"
}

enum HyMT2SchemaShadowStatus: String, Codable, Sendable {
    case failed
    case passed
}

struct HyMT2SchemaShadowOccurrence: Equatable, Sendable {
    let identifier: String
    let allowedSurfaces: [String]
    let expectedSurfaces: Set<String>
    let anchorAlternatives: [String]
    let resolution: TranslationPronounResolution?

    var placeholder: String { "{{\(identifier)}}" }
}

struct HyMT2SchemaShadowPlan: Sendable {
    let fixtureID: String
    let family: HyMT2SchemaShadowFamily
    let source: String
    let prompt: String
    let occurrences: [HyMT2SchemaShadowOccurrence]
    let globalAnchorGroups: [[String]]
}

struct HyMT2SchemaShadowBinding: Codable, Equatable, Sendable {
    let surface: String
}

struct HyMT2SchemaShadowEnvelope: Codable, Equatable, Sendable {
    let protocolNonce: String
    let targetTemplate: String
    let bindings: [String: HyMT2SchemaShadowBinding]

    enum CodingKeys: String, CodingKey {
        case bindings
        case protocolNonce = "protocol_nonce"
        case targetTemplate = "target_template"
    }
}

struct HyMT2SchemaShadowParsed: Equatable, Sendable {
    let targetTemplate: String
    let target: String
    let bindings: [String: HyMT2SchemaShadowBinding]
}

struct HyMT2SchemaShadowSchemaRequest: Sendable {
    let prompt: String
    let maximumTokens: Int
    let stop: [String]
    let schema: HyMT2SchemaShadowSchema
    let nonce: String
}

struct HyMT2SchemaShadowOutcome {
    let code: HyMT2SchemaShadowFailureCode?
    let outputHash: String?
    let schemaHash: String?
    let latency: Duration
}

struct HyMT2SchemaShadowPreparedSchema {
    let nonce: String
    let schema: HyMT2SchemaShadowSchema
    let hash: String
}
