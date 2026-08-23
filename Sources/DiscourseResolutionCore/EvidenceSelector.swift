import DiscourseResolutionAPI

enum EvidenceSelector {
    static func select(
        for candidate: PronounCandidate,
        request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        if candidate.original == "祂" {
            return selectDeityEvidence(for: candidate, request: request)
        }
        return selectHumanEvidence(for: candidate, request: request)
    }

    private static func selectHumanEvidence(
        for candidate: PronounCandidate,
        request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        let currentAnchors = ReferentAnchorScanner.scan(request.currentText)
        let precedingAnchors = anchors(
            before: candidate,
            from: currentAnchors
        )
        if precedingAnchors.contains(where: \.isPlural) {
            return .abstain([], [.pluralReferenceProtected])
        }
        guard !precedingAnchors.isEmpty else {
            if currentAnchors.isEmpty { return inspectHumanContext(request) }
            return .abstain([.anchorAfterPronoun], [])
        }
        if let selection = uniformHumanGenderEvidence(
            anchors: precedingAnchors,
            request: request
        ) {
            return .evidence(selection)
        }
        if let ambiguity = ambiguity(for: precedingAnchors) {
            return .abstain([ambiguity], [])
        }
        if let anchor = precedingAnchors.first {
            return .evidence(
                SelectedEvidence(
                    referent: anchor.referent,
                    reason: .uniqueCurrentTurnAnchor,
                    confidence: 1,
                    evidence: evidence(sequence: request.currentSequence, text: request.currentText)
                )
            )
        }
        return .abstain([.anchorAfterPronoun], [])
    }

    private static func selectDeityEvidence(
        for candidate: PronounCandidate,
        request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        let currentAnchors = ReferentAnchorScanner.scan(request.currentText)
        let precedingAnchors = anchors(
            before: candidate,
            from: currentAnchors
        )
        if precedingAnchors.contains(where: \.isPlural) {
            return .abstain([], [.pluralReferenceProtected])
        }
        guard !precedingAnchors.isEmpty else {
            if currentAnchors.isEmpty { return selectDeityFromContext(request) }
            return .abstain([.anchorAfterPronoun], [])
        }
        if let selection = uniformHumanGenderEvidence(
            anchors: precedingAnchors,
            request: request
        ) {
            return .evidence(selection)
        }
        if let ambiguity = ambiguity(for: precedingAnchors) {
            return .abstain([ambiguity], [])
        }
        guard let anchor = precedingAnchors.first else {
            return .abstain([.anchorAfterPronoun], [])
        }
        return .evidence(
            SelectedEvidence(
                referent: anchor.referent,
                reason: .uniqueCurrentTurnAnchor,
                confidence: 1,
                evidence: evidence(sequence: request.currentSequence, text: request.currentText)
            )
        )
    }

    private static func anchors(
        before candidate: PronounCandidate,
        from anchors: [ReferentAnchor]
    ) -> [ReferentAnchor] {
        anchors.filter { $0.range.lowerBound < candidate.range.lowerBound }
    }

    private static func uniformHumanGenderEvidence(
        anchors: [ReferentAnchor],
        request: DiscourseResolutionRequest
    ) -> SelectedEvidence? {
        guard anchors.count > 1 else { return nil }
        let referents = Set(anchors.map(\.referent))
        guard referents.count == 1, let referent = referents.first else { return nil }
        guard referent.discourseGender != nil else { return nil }
        return SelectedEvidence(
            referent: referent,
            reason: .uniformCurrentTurnGenderAnchors,
            confidence: 1,
            evidence: evidence(sequence: request.currentSequence, text: request.currentText)
        )
    }

    static func ambiguity(for anchors: [ReferentAnchor]) -> DiscourseAmbiguity? {
        guard anchors.count > 1 else { return nil }
        let referents = Set(anchors.map(\.referent))
        guard referents.count == 1 else {
            return referents.contains(.deity)
                ? .competingReferentAnchors
                : .competingGenderAnchors
        }
        return referents.contains(.deity)
            ? .multipleDeityAnchors
            : .multipleSameGenderAnchors
    }

    static func evidence(sequence: Int, text: String) -> DiscourseCorrectionEvidence {
        DiscourseCorrectionEvidence(sequence: sequence, text: text)
    }
}
