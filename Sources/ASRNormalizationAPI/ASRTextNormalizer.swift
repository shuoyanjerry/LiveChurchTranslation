/// One immutable correction from a known recognition alias to canonical Mandarin text.
public struct ASRNormalizationRule: Equatable, Hashable, Sendable {
    public let recognitionAlias: String
    public let canonicalText: String

    public init(recognitionAlias: String, canonicalText: String) {
        self.recognitionAlias = recognitionAlias
        self.canonicalText = canonicalText
    }
}

/// Replaceable post-ASR normalization boundary.
public protocol ASRTextNormalizer: Sendable {
    /// Returns corrected text without mutating the input or the supplied rules.
    func normalize(
        _ text: String,
        using additionalRules: [ASRNormalizationRule]
    ) -> String
}
