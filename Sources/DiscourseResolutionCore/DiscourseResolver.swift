import DiscourseResolutionAPI

/// A stateless, deterministic resolver for narrowly supported Mandarin pronouns.
public struct DiscourseResolver: DiscourseResolving {
    public init() {}

    public func resolve(_ request: DiscourseResolutionRequest) -> DiscourseResolutionResult {
        ResolutionEngine(request: request).resolve()
    }
}

private struct ResolutionEngine {
    let request: DiscourseResolutionRequest

    func resolve() -> DiscourseResolutionResult {
        let safetyConstraints = TextSafety.blockingConstraints(in: request.currentText)
        guard safetyConstraints.isEmpty else {
            return unchanged(constraints: safetyConstraints)
        }

        let pronounScan = PronounLocator.scan(request.currentText)
        guard let firstCandidate = pronounScan.candidates.first else {
            return unchanged(constraints: pronounScan.constraints)
        }
        guard Set(pronounScan.candidates.map(\.original)).count == 1 else {
            return unchanged(ambiguities: [.mixedPronounSpellings])
        }

        switch EvidenceSelector.select(for: firstCandidate, request: request) {
        case .abstain(let ambiguities, let constraints):
            return unchanged(ambiguities: ambiguities, constraints: constraints)
        case .evidence(let selection):
            return apply(
                candidate: firstCandidate,
                protectsAdditionalCandidates: pronounScan.candidates.count > 1,
                evidence: selection
            )
        }
    }

    private func apply(
        candidate: PronounCandidate,
        protectsAdditionalCandidates: Bool,
        evidence: SelectedEvidence
    ) -> DiscourseResolutionResult {
        let replacement = evidence.gender.pronoun
        let constraints: [DiscourseResolutionConstraint] =
            protectsAdditionalCandidates
            ? [.additionalPronounCandidatesProtected]
            : []
        guard candidate.original != replacement else {
            return unchanged(constraints: constraints)
        }

        var resolved = request.currentText
        resolved.replaceSubrange(candidate.range, with: replacement)
        let correction =
            DiscourseCorrection(
                kind: .singularGenderedPronoun,
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
            constraints: constraints
        )
    }

    private func auditRange(for range: Range<String.Index>) -> DiscourseTextRange {
        DiscourseTextRange(
            location: request.currentText[..<range.lowerBound].utf16.count,
            length: request.currentText[range].utf16.count
        )
    }

    private func unchanged(
        ambiguities: [DiscourseAmbiguity] = [],
        constraints: [DiscourseResolutionConstraint] = []
    ) -> DiscourseResolutionResult {
        DiscourseResolutionResult(
            originalText: request.currentText,
            resolvedText: request.currentText,
            corrections: [],
            ambiguities: ambiguities,
            constraints: constraints
        )
    }
}
