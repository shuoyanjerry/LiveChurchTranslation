/// An unresolved referent that caused the resolver to abstain.
public enum DiscourseAmbiguity: String, Equatable, Hashable, Sendable {
    case noExplicitGenderAnchor
    case noExplicitDeityAnchor
    case anchorAfterPronoun
    case multipleSameGenderAnchors
    case competingGenderAnchors
    case multipleDeityAnchors
    case competingReferentAnchors
    case mixedPronounSpellings
}

/// A safety boundary that prevented evidence or text from being used.
public enum DiscourseResolutionConstraint: String, Equatable, Hashable, Sendable {
    case contextLimitExceeded
    case outOfOrderContext
    case staleContextIgnored
    case quotationProtected
    case pluralReferenceProtected
    case lexicalOccurrenceProtected
    case ineligiblePronounPosition
    case additionalPronounCandidatesProtected
}

/// Keeps source text, resolved text, edits, and abstentions together.
public struct DiscourseResolutionResult: Equatable, Hashable, Sendable {
    public let originalText: String
    public let resolvedText: String
    public let corrections: [DiscourseCorrection]
    public let ambiguities: [DiscourseAmbiguity]
    public let constraints: [DiscourseResolutionConstraint]
    public let pronounGuidance: [DiscoursePronounGuidance]

    public init(
        originalText: String,
        resolvedText: String,
        corrections: [DiscourseCorrection],
        ambiguities: [DiscourseAmbiguity],
        constraints: [DiscourseResolutionConstraint],
        pronounGuidance: [DiscoursePronounGuidance] = []
    ) {
        self.originalText = originalText
        self.resolvedText = resolvedText
        self.corrections = corrections
        self.ambiguities = ambiguities
        self.constraints = constraints
        self.pronounGuidance = pronounGuidance
    }
}
