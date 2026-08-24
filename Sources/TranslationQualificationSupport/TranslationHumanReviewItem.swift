enum HumanReviewAxis: String, CaseIterable, Sendable {
    case fidelity
    case completeness
    case naturalness
    case theology
    case properNames
}

enum HumanReviewRequirementKind: String, Sendable {
    case semanticAxis
    case preservationCheck
    case glossaryTerm
    case pronounGuidance
    case pronounEnglishPolicy
    case backendQualityWarning
}

public enum TranslationHumanReviewVerdict: String, Codable, Sendable {
    case pass
    case fail
}

public struct TranslationHumanReviewItem: Codable, Equatable, Sendable {
    public let itemID: String
    public let verdict: TranslationHumanReviewVerdict

    public init(itemID: String, verdict: TranslationHumanReviewVerdict) {
        self.itemID = itemID
        self.verdict = verdict
    }

    public init(from decoder: Decoder) throws {
        try requireExactHumanReviewKeys(decoder, ["itemID", "verdict"])
        let values = try decoder.container(keyedBy: CodingKeys.self)
        itemID = try values.decode(String.self, forKey: .itemID)
        verdict = try values.decode(TranslationHumanReviewVerdict.self, forKey: .verdict)
    }
}
