import Foundation

/// A deterministic source-to-target translation boundary.
public protocol TranslationProvider: Sendable {
    var identifier: String { get }

    func loadModel(at location: URL) async throws
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
    func shutdown() async
}

public struct TranslationRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceText: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let glossary: [TranslationTerm]

    public init(
        id: UUID = UUID(),
        sourceText: String,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en",
        glossary: [TranslationTerm]
    ) {
        self.id = id
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.glossary = glossary
    }
}

public struct TranslationTerm: Codable, Equatable, Hashable, Sendable {
    public let source: String
    public let target: String

    public init(source: String, target: String) {
        self.source = source
        self.target = target
    }
}

public struct TranslationResult: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let requestID: UUID
    public let sourceText: String
    public let targetText: String
    public let duration: Duration

    public init(
        id: UUID = UUID(),
        requestID: UUID,
        sourceText: String,
        targetText: String,
        duration: Duration
    ) {
        self.id = id
        self.requestID = requestID
        self.sourceText = sourceText
        self.targetText = targetText
        self.duration = duration
    }
}

public enum TranslationProviderError: LocalizedError, Sendable {
    case languageModelUnavailable
    case runtimeNotAttached
    case emptySource
    case invalidOutput
    case translationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .languageModelUnavailable: "The on-device Chinese–English language pack is unavailable."
        case .runtimeNotAttached: "The on-device translation runtime is still preparing."
        case .emptySource: "There is no source text to translate."
        case .invalidOutput: "The translation model returned an invalid response."
        case .translationFailed(let message): "Translation failed: \(message)"
        }
    }
}
