/// The deliberately narrow class of edits supported by discourse resolution.
public enum DiscourseCorrectionKind: String, Equatable, Hashable, Sendable {
    case singularGenderedPronoun
}

/// A range in the original text, measured in UTF-16 code units.
public struct DiscourseTextRange: Equatable, Hashable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

/// Why an otherwise ambiguous pronoun was safe enough to correct.
public enum DiscourseCorrectionReason: String, Equatable, Hashable, Sendable {
    case uniqueCurrentTurnAnchor
    case uniqueRecentVerifiedAnchor
}

/// The exact turn used to justify a correction.
public struct DiscourseCorrectionEvidence: Equatable, Hashable, Sendable {
    public let sequence: Int
    public let text: String

    public init(sequence: Int, text: String) {
        self.sequence = sequence
        self.text = text
    }
}

/// One auditable replacement, expressed against the untouched original text.
public struct DiscourseCorrection: Equatable, Hashable, Sendable {
    public let kind: DiscourseCorrectionKind
    public let range: DiscourseTextRange
    public let original: String
    public let replacement: String
    public let reason: DiscourseCorrectionReason
    public let confidence: Double
    public let evidence: DiscourseCorrectionEvidence

    public init(
        kind: DiscourseCorrectionKind,
        range: DiscourseTextRange,
        original: String,
        replacement: String,
        reason: DiscourseCorrectionReason,
        confidence: Double,
        evidence: DiscourseCorrectionEvidence
    ) {
        self.kind = kind
        self.range = range
        self.original = original
        self.replacement = replacement
        self.reason = reason
        self.confidence = confidence
        self.evidence = evidence
    }
}
