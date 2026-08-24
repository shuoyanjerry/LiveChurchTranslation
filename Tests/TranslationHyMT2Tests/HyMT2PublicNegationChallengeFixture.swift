enum PublicNegationChallengePolicy: Equatable, Sendable {
    /// The stated number of independent negative propositions must survive semantically.
    case mustPreserveCount(Int)

    /// The surface `不` belongs to a construction or lexical item, not a negative proposition.
    case nonFunctional

    /// Surface-token checks cannot safely decide the scope or paraphrase equivalence.
    case humanReview
}

enum PublicNegationHumanOracle: Equatable, Sendable {
    case accept
    case reject
}

struct PublicNegationChallengeFixture: Sendable {
    let id: String
    let source: String
    let target: String
    let policy: PublicNegationChallengePolicy
    let humanOracle: PublicNegationHumanOracle
}

enum PublicNegationChallengeFixtures {
    static let all = repairedCountLosses + scopeLimitations + formerFalseRejects
}
