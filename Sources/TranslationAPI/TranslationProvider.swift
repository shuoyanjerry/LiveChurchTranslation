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
    public let context: [TranslationContextEntry]
    public let pronounGuidance: [TranslationPronounGuidance]

    public init(
        id: UUID = UUID(),
        sourceText: String,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en",
        glossary: [TranslationTerm],
        context: [TranslationContextEntry] = [],
        pronounGuidance: [TranslationPronounGuidance] = []
    ) {
        self.id = id
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.glossary = glossary
        self.context = context
        self.pronounGuidance = pronounGuidance
    }
}

/// One finalized, validator-approved bilingual turn available to a later request.
public struct TranslationContextEntry: Codable, Equatable, Hashable, Sendable {
    public let sourceText: String
    public let targetText: String

    public init(sourceText: String, targetText: String) {
        self.sourceText = sourceText
        self.targetText = targetText
    }
}

public struct TranslationTerm: Codable, Equatable, Hashable, Sendable {
    public let source: String
    public let target: String
    public let sourceAliases: [String]
    public let acceptedTargets: [String]
    public let requirement: TranslationTermRequirement

    public init(
        source: String,
        target: String,
        sourceAliases: [String] = [],
        acceptedTargets: [String] = [],
        requirement: TranslationTermRequirement = .required
    ) {
        self.source = source
        self.target = target
        self.sourceAliases = sourceAliases
        self.acceptedTargets = acceptedTargets
        self.requirement = requirement
    }
}

public enum TranslationTermRequirement: String, Codable, Sendable {
    case required
    case preferred
}

public struct TranslationResult: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let requestID: UUID
    public let sourceText: String
    public let targetText: String
    public let duration: Duration
    public let review: TranslationReview?

    public init(
        id: UUID = UUID(),
        requestID: UUID,
        sourceText: String,
        targetText: String,
        duration: Duration,
        review: TranslationReview? = nil
    ) {
        self.id = id
        self.requestID = requestID
        self.sourceText = sourceText
        self.targetText = targetText
        self.duration = duration
        self.review = review
    }
}

/// Non-blocking quality evidence attached when useful model text is shown despite a warning.
public struct TranslationReview: Codable, Equatable, Hashable, Sendable {
    public let issueCodes: [String]

    public init(issueCodes: [String]) {
        self.issueCodes = Array(Set(issueCodes.filter { !$0.isEmpty })).sorted()
    }
}

public enum TranslationFailureImpact: Equatable, Sendable {
    case terminalUtterance
    case retryableUtterance
    case runtime
}

public protocol TranslationFailureImpactProviding: Error, Sendable {
    var translationFailureImpact: TranslationFailureImpact { get }
    var translationFailureCode: String { get }
}

public enum TranslationProviderError: LocalizedError, TranslationFailureImpactProviding, Sendable {
    case languageModelUnavailable
    case runtimeNotAttached
    case emptySource
    case invalidOutput
    case translationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .languageModelUnavailable: "本地中英翻译语言包不可用。"
        case .runtimeNotAttached: "本地翻译服务仍在准备中。"
        case .emptySource: "没有可翻译的原文。"
        case .invalidOutput: "翻译模型没有返回可安全显示的译文，原文已保留等待重译。"
        case .translationFailed(let message): "翻译失败：\(message)"
        }
    }

    public var translationFailureImpact: TranslationFailureImpact {
        switch self {
        case .emptySource:
            .terminalUtterance
        case .invalidOutput:
            .retryableUtterance
        case .languageModelUnavailable, .runtimeNotAttached, .translationFailed:
            .runtime
        }
    }

    public var translationFailureCode: String {
        switch self {
        case .languageModelUnavailable: "translation.model_unavailable"
        case .runtimeNotAttached: "translation.runtime_not_attached"
        case .emptySource: "translation.empty_source"
        case .invalidOutput: "translation.invalid_output"
        case .translationFailed: "translation.failed"
        }
    }
}
