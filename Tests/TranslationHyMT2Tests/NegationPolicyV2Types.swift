enum NegationPolicyV2Disposition: Equatable, Sendable {
    case noFunctionalNegation
    case requiresOvertCue(count: Int)
    case humanReviewRequired(reason: NegationPolicyV2ReviewReason)
}

enum NegationPolicyV2ReviewReason: Equatable, Sendable {
    case mixedPolarityClauses(functionalCount: Int)
    case questionScope(functionalCount: Int)
    case quantifierScope
    case targetCueCountMismatch(expected: Int, observed: Int)
    case unexpectedTargetCue(observed: Int)
    case unclassifiedSourceCue
    case unsafeSourceUnicode
    case unsafeTargetUnicode
}

struct NegationPolicyV2ChineseScan: Equatable, Sendable {
    let cueOffsets: [Int]
    let clauseCueCounts: [Int]
    let hasUnclassifiedCue: Bool
}
