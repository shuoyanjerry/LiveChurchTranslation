enum MorphologySlot {
    case subject
    case object
    case possessiveDeterminer
    case possessiveIndependent
    case reflexive
}

enum PronounFamily {
    case feminine
    case masculine
    case neutral
}

enum PronounForm: String {
    case he, him, his, himself
    case she, her, hers, herself
    case they, them, their, theirs, themself, themselves

    var family: PronounFamily {
        switch self {
        case .she, .her, .hers, .herself: .feminine
        case .he, .him, .his, .himself: .masculine
        case .they, .them, .their, .theirs, .themself, .themselves: .neutral
        }
    }

    var nonPossessiveSlot: MorphologySlot? {
        switch self {
        case .he, .she, .they: .subject
        case .him, .her, .them: .object
        case .himself, .herself, .themself, .themselves: .reflexive
        case .his, .hers, .their, .theirs: nil
        }
    }
}
