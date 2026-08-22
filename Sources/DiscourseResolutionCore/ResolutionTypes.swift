import DiscourseResolutionAPI

enum ResolutionGender: Hashable, Sendable {
    case female
    case male

    var pronoun: String {
        switch self {
        case .female: "她"
        case .male: "他"
        }
    }
}

struct PronounCandidate {
    let range: Range<String.Index>
    let original: String
}

struct GenderAnchor {
    let gender: ResolutionGender
    let range: Range<String.Index>
    let isPlural: Bool
}

struct SelectedEvidence {
    let gender: ResolutionGender
    let reason: DiscourseCorrectionReason
    let confidence: Double
    let evidence: DiscourseCorrectionEvidence
}

struct ContextAnchor {
    let anchor: GenderAnchor
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
    let candidates: [PronounCandidate]
    let constraints: [DiscourseResolutionConstraint]
}
