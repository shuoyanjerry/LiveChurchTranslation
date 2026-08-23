import DiscourseResolutionAPI

struct ResolutionEngine {
    let request: DiscourseResolutionRequest

    func resolve() -> DiscourseResolutionResult {
        let scan = PronounLocator.scan(request.currentText)
        let baseGuidance = guidance(for: scan.observed)
        if let result = preflightResult(scan: scan, guidance: baseGuidance) {
            return result
        }
        guard let candidate = scan.eligible.first else {
            return unchanged(constraints: scan.constraints, guidance: baseGuidance)
        }
        return selectEvidence(
            for: candidate,
            scan: scan,
            baseGuidance: baseGuidance
        )
    }

    private func preflightResult(
        scan: PronounScan,
        guidance: [DiscoursePronounGuidance]
    ) -> DiscourseResolutionResult? {
        let safety = TextSafety.blockingConstraints(in: request.currentText)
        if !safety.isEmpty {
            return unchanged(
                constraints: safety + scan.constraints,
                guidance: guidance
            )
        }
        if scan.eligible.isEmpty {
            return unchanged(constraints: scan.constraints, guidance: guidance)
        }
        if Set(scan.observed.map(\.original)).count > 1 {
            return unchanged(
                ambiguities: [.mixedPronounSpellings],
                constraints: scan.constraints,
                guidance: guidance
            )
        }
        return nil
    }

    private func selectEvidence(
        for candidate: PronounCandidate,
        scan: PronounScan,
        baseGuidance: [DiscoursePronounGuidance]
    ) -> DiscourseResolutionResult {
        switch EvidenceSelector.select(for: candidate, request: request) {
        case .abstain(let ambiguities, let constraints):
            unchanged(
                ambiguities: ambiguities,
                constraints: scan.constraints + constraints,
                guidance: baseGuidance
            )
        case .evidence(let selection):
            apply(
                candidate: candidate,
                observed: scan.observed,
                baseConstraints: scan.constraints,
                evidence: selection
            )
        }
    }
}
