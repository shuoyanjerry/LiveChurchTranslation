/// A finalized, durably stored turn that passed the translation validator.
///
/// Persistence verifies storage and translation success only. It does not
/// confirm that a following pronoun refers to an appellation in this turn.
public struct VerifiedDiscourseTurn: Equatable, Hashable, Sendable {
    public let sequence: Int
    public let text: String

    public init(sequence: Int, text: String) {
        self.sequence = sequence
        self.text = text
    }
}

/// Immutable input for one discourse-resolution decision.
public struct DiscourseResolutionRequest: Equatable, Hashable, Sendable {
    public let currentSequence: Int
    public let currentText: String
    public let verifiedTurns: [VerifiedDiscourseTurn]

    /// `verifiedTurns` may contain at most the two preceding verified turns.
    public init(
        currentSequence: Int,
        currentText: String,
        verifiedTurns: [VerifiedDiscourseTurn]
    ) {
        self.currentSequence = currentSequence
        self.currentText = currentText
        self.verifiedTurns = verifiedTurns
    }
}
