enum NegationPolicyV2 {
    /// A test-only structural gate. `requiresOvertCue` is not a full semantic verdict.
    static func disposition(
        source: String,
        target: String
    ) -> NegationPolicyV2Disposition {
        let sourceDisposition = sourceDisposition(source)
        guard !NegationPolicyV2Unicode.targetIsUnsafe(target) else {
            return .humanReviewRequired(reason: .unsafeTargetUnicode)
        }
        let observed = NegationPolicyV2English.overtCueCount(in: target)
        switch sourceDisposition {
        case .noFunctionalNegation:
            return observed == 0
                ? .noFunctionalNegation
                : .humanReviewRequired(reason: .unexpectedTargetCue(observed: observed))
        case .requiresOvertCue(let expected):
            return observed == expected
                ? .requiresOvertCue(count: expected)
                : .humanReviewRequired(
                    reason: .targetCueCountMismatch(expected: expected, observed: observed)
                )
        case .humanReviewRequired:
            return sourceDisposition
        }
    }

    static func sourceDisposition(_ source: String) -> NegationPolicyV2Disposition {
        guard !NegationPolicyV2Unicode.sourceIsUnsafe(source) else {
            return .humanReviewRequired(reason: .unsafeSourceUnicode)
        }
        if quantifierScopePhrases.contains(where: source.contains) {
            return .humanReviewRequired(reason: .quantifierScope)
        }
        let scan = NegationPolicyV2Chinese.scan(source)
        guard !scan.hasUnclassifiedCue else {
            return .humanReviewRequired(reason: .unclassifiedSourceCue)
        }
        let count = scan.cueOffsets.count
        guard count > 0 else { return .noFunctionalNegation }
        if source.contains("？") || source.contains("?") {
            return .humanReviewRequired(reason: .questionScope(functionalCount: count))
        }
        let clauseCounts = scan.clauseCueCounts
        if clauseCounts.contains(0), clauseCounts.contains(where: { $0 > 0 }) {
            return .humanReviewRequired(
                reason: .mixedPolarityClauses(functionalCount: count)
            )
        }
        return .requiresOvertCue(count: count)
    }

    private static let quantifierScopePhrases = [
        "不是所有", "并非所有", "并非每", "不都", "不一定", "不完全", "不总是",
        "没有一个", "没有任何", "未必",
    ]
}
