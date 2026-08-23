/// A source-text range measured in UTF-16 code units.
public struct TranslationSourceRange: Codable, Equatable, Hashable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

/// Evidence status for one spoken Mandarin third-person pronoun.
public enum TranslationPronounResolution: String, Codable, Equatable, Hashable, Sendable {
    case unresolvedSpokenMandarin
    case verifiedFemale
    case verifiedMale
    case verifiedDeity
}

/// Immutable translation guidance produced before model inference.
public struct TranslationPronounGuidance: Codable, Equatable, Hashable, Sendable {
    public let sourceRange: TranslationSourceRange
    public let resolution: TranslationPronounResolution

    public init(
        sourceRange: TranslationSourceRange,
        resolution: TranslationPronounResolution
    ) {
        self.sourceRange = sourceRange
        self.resolution = resolution
    }
}
