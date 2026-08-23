/// Biological gender established by explicit discourse evidence.
public enum DiscourseReferentGender: String, Equatable, Hashable, Sendable {
    case female
    case male
}

/// An evidence-bound decision for one observed Mandarin third-person pronoun.
public enum DiscoursePronounResolution: Equatable, Hashable, Sendable {
    /// Spoken Mandarin supplied no reliable gender evidence for this occurrence.
    case unresolved

    /// Explicit evidence identified the referent without using stereotypes.
    case verified(
        gender: DiscourseReferentGender,
        reason: DiscourseCorrectionReason,
        confidence: Double,
        evidence: DiscourseCorrectionEvidence
    )

    /// Explicit evidence identifies the Christian deity, not a biological sex.
    case verifiedDeity(
        reason: DiscourseCorrectionReason,
        confidence: Double,
        evidence: DiscourseCorrectionEvidence
    )
}

/// Immutable guidance tied to a UTF-16 range in the untouched recognizer text.
public struct DiscoursePronounGuidance: Equatable, Hashable, Sendable {
    public let range: DiscourseTextRange
    public let resolution: DiscoursePronounResolution

    public init(
        range: DiscourseTextRange,
        resolution: DiscoursePronounResolution
    ) {
        self.range = range
        self.resolution = resolution
    }
}
