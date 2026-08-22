/// One immutable correction from a known recognition alias to canonical Mandarin text.
public struct ASRNormalizationRule: Equatable, Hashable, Sendable {
    public let recognitionAlias: String
    public let canonicalText: String

    public init(recognitionAlias: String, canonicalText: String) {
        self.recognitionAlias = recognitionAlias
        self.canonicalText = canonicalText
    }
}

/// One auditable correction made to recognizer output.
public struct ASRNormalizationChange: Equatable, Hashable, Sendable {
    public let recognitionAlias: String
    public let canonicalText: String

    public init(recognitionAlias: String, canonicalText: String) {
        self.recognitionAlias = recognitionAlias
        self.canonicalText = canonicalText
    }
}

/// Keeps the untouched recognizer output beside the reviewed normalized text.
public struct ASRNormalizationResult: Equatable, Sendable {
    public let originalText: String
    public let normalizedText: String
    public let changes: [ASRNormalizationChange]

    public init(
        originalText: String,
        normalizedText: String,
        changes: [ASRNormalizationChange]
    ) {
        self.originalText = originalText
        self.normalizedText = normalizedText
        self.changes = changes
    }
}

/// Replaceable post-ASR normalization boundary.
public protocol ASRTextNormalizer: Sendable {
    /// Returns corrected text and a complete change audit without mutating input.
    func normalizeWithAudit(
        _ text: String,
        using additionalRules: [ASRNormalizationRule]
    ) -> ASRNormalizationResult
}

extension ASRTextNormalizer {
    public func normalize(
        _ text: String,
        using additionalRules: [ASRNormalizationRule]
    ) -> String {
        normalizeWithAudit(text, using: additionalRules).normalizedText
    }
}
