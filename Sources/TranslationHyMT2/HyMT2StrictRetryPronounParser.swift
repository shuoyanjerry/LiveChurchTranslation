enum HyMT2StrictRetryPronounParser {
    static func parse(
        _ output: String,
        plan: HyMT2PronounPlan,
        flatCapability: HyMT2FlatPronounRetryCapability?
    ) throws -> HyMT2ParsedPronounOutput {
        let canonical = HyMT2PronounMarkerTokenizer.tokens(in: output)
        let flat = HyMT2FlatPronounTokenizer.tokens(in: output)
        if HyMT2SpacedCanonicalPronounParser.hasCandidate(canonical, in: output) {
            guard flat.isEmpty else { throw malformedFailure() }
            return try HyMT2SpacedCanonicalPronounParser.parse(
                output,
                plan: plan,
                tokens: canonical
            )
        }
        if !canonical.isEmpty {
            guard flat.isEmpty else { throw malformedFailure() }
            try HyMT2FlatPronounTokenizer.validateNoResidualIdentifiers(
                in: output,
                excluding: canonical.map(\.range)
            )
            return try HyMT2PronounMarkerParser.parse(output, plan: plan)
        }
        guard let flatCapability, flatCapability.authorizes(plan) else {
            throw malformedFailure()
        }
        return try HyMT2FlatPronounParser.parse(output, plan: plan, tokens: flat)
    }

    private static func malformedFailure() -> OutputValidationFailure {
        OutputValidationFailure(issues: [.malformedPronounMarker])
    }
}
