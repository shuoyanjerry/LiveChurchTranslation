import DiscourseResolutionAPI

enum ResolutionReferent: Hashable, Sendable {
    case female
    case male
    case deity

    var pronoun: String {
        switch self {
        case .female: "她"
        case .male: "他"
        case .deity: "祂"
        }
    }

    var discourseGender: DiscourseReferentGender? {
        switch self {
        case .female: .female
        case .male: .male
        case .deity: nil
        }
    }
}

struct PronounCandidate {
    let range: Range<String.Index>
    let original: String
}

struct ReferentAnchor {
    let referent: ResolutionReferent
    let range: Range<String.Index>
    let isPlural: Bool
}

struct SelectedEvidence {
    let referent: ResolutionReferent
    let reason: DiscourseCorrectionReason
    let confidence: Double
    let evidence: DiscourseCorrectionEvidence
}

struct ContextAnchor {
    let anchor: ReferentAnchor
    let turn: VerifiedDiscourseTurn
    let distance: Int
}

enum ContextAnchorDecision {
    case anchors([ContextAnchor], [DiscourseResolutionConstraint])
    case abstain([DiscourseResolutionConstraint])
}

enum EvidenceDecision {
    case evidence(SelectedEvidence)
    case abstain([DiscourseAmbiguity], [DiscourseResolutionConstraint])
}

struct PronounScan {
    let observed: [PronounCandidate]
    let eligible: [PronounCandidate]
    let constraints: [DiscourseResolutionConstraint]
}
