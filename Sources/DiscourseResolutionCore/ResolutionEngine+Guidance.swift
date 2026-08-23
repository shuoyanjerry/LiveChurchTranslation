import DiscourseResolutionAPI

extension ResolutionEngine {
    func guidance(
        for candidates: [PronounCandidate],
        verifiedCandidate: PronounCandidate? = nil,
        evidence: SelectedEvidence? = nil
    ) -> [DiscoursePronounGuidance] {
        candidates.map { candidate in
            DiscoursePronounGuidance(
                range: auditRange(for: candidate.range),
                resolution: resolution(
                    for: candidate,
                    verifiedCandidate: verifiedCandidate,
                    evidence: evidence
                )
            )
        }
    }

    private func resolution(
        for candidate: PronounCandidate,
        verifiedCandidate: PronounCandidate?,
        evidence: SelectedEvidence?
    ) -> DiscoursePronounResolution {
        if candidate.range == verifiedCandidate?.range, let evidence {
            return verifiedResolution(evidence)
        }
        return .unresolved
    }

    private func verifiedResolution(
        _ evidence: SelectedEvidence
    ) -> DiscoursePronounResolution {
        guard let gender = evidence.referent.discourseGender else {
            return .verifiedDeity(
                reason: evidence.reason,
                confidence: evidence.confidence,
                evidence: evidence.evidence
            )
        }
        return .verified(
            gender: gender,
            reason: evidence.reason,
            confidence: evidence.confidence,
            evidence: evidence.evidence
        )
    }
}
