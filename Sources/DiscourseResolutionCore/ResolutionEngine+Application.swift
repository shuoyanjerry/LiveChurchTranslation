import DiscourseResolutionAPI

extension ResolutionEngine {
    func apply(
        candidate: PronounCandidate,
        observed: [PronounCandidate],
        baseConstraints: [DiscourseResolutionConstraint],
        evidence: SelectedEvidence
    ) -> DiscourseResolutionResult {
        let replacement = evidence.referent.pronoun
        var constraints = baseConstraints
        if observed.count > 1 {
            constraints.append(.additionalPronounCandidatesProtected)
        }
        let decisions = guidance(
            for: observed,
            verifiedCandidate: candidate,
            evidence: evidence
        )
        guard candidate.original != replacement else {
            return unchanged(constraints: constraints, guidance: decisions)
        }
        return correctedResult(
            candidate: candidate,
            replacement: replacement,
            constraints: constraints,
            guidance: decisions,
            evidence: evidence
        )
    }

    func unchanged(
        ambiguities: [DiscourseAmbiguity] = [],
        constraints: [DiscourseResolutionConstraint] = [],
        guidance: [DiscoursePronounGuidance] = []
    ) -> DiscourseResolutionResult {
        DiscourseResolutionResult(
            originalText: request.currentText,
            resolvedText: request.currentText,
            corrections: [],
            ambiguities: ambiguities,
            constraints: constraints,
            pronounGuidance: guidance
        )
    }

    func auditRange(for range: Range<String.Index>) -> DiscourseTextRange {
        DiscourseTextRange(
            location: request.currentText[..<range.lowerBound].utf16.count,
            length: request.currentText[range].utf16.count
        )
    }

    private func correctedResult(
        candidate: PronounCandidate,
        replacement: String,
        constraints: [DiscourseResolutionConstraint],
        guidance: [DiscoursePronounGuidance],
        evidence: SelectedEvidence
    ) -> DiscourseResolutionResult {
        var resolved = request.currentText
        resolved.replaceSubrange(candidate.range, with: replacement)
        let correction = DiscourseCorrection(
            kind: evidence.referent == .deity ? .deityPronoun : .singularGenderedPronoun,
            range: auditRange(for: candidate.range),
            original: candidate.original,
            replacement: replacement,
            reason: evidence.reason,
            confidence: evidence.confidence,
            evidence: evidence.evidence
        )
        return DiscourseResolutionResult(
            originalText: request.currentText,
            resolvedText: resolved,
            corrections: [correction],
            ambiguities: [],
            constraints: constraints,
            pronounGuidance: guidance
        )
    }
}
