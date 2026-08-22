import DiscourseResolutionAPI

enum EvidenceSelector {
    static func select(
        for candidate: PronounCandidate,
        request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        let currentAnchors = GenderAnchorScanner.scan(request.currentText)
        if currentAnchors.contains(where: \.isPlural) {
            return .abstain([], [.pluralReferenceProtected])
        }
        if let ambiguity = ambiguity(for: currentAnchors) {
            return .abstain([ambiguity], [])
        }
        if let anchor = currentAnchors.first {
            guard anchor.range.lowerBound < candidate.range.lowerBound else {
                return .abstain([.anchorAfterPronoun], [])
            }
            return .evidence(
                SelectedEvidence(
                    gender: anchor.gender,
                    reason: .uniqueCurrentTurnAnchor,
                    confidence: 1,
                    evidence: evidence(sequence: request.currentSequence, text: request.currentText)
                )
            )
        }
        return selectFromContext(request)
    }

    private static func selectFromContext(
        _ request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        guard request.verifiedTurns.count <= 2 else {
            return .abstain([], [.contextLimitExceeded])
        }
        guard hasValidOrder(request) else {
            return .abstain([], [.outOfOrderContext])
        }

        let anchors: [ContextAnchor]
        let constraints: [DiscourseResolutionConstraint]
        switch collectContextAnchors(request) {
        case .abstain(let blockers):
            return .abstain([], blockers)
        case .anchors(let collectedAnchors, let collectedConstraints):
            anchors = collectedAnchors
            constraints = collectedConstraints
        }
        if let ambiguity = ambiguity(for: anchors.map(\.anchor)) {
            return .abstain([ambiguity], constraints)
        }
        guard let contextAnchor = anchors.first else {
            return .abstain([.noExplicitGenderAnchor], constraints)
        }
        return .evidence(
            SelectedEvidence(
                gender: contextAnchor.anchor.gender,
                reason: .uniqueRecentVerifiedAnchor,
                confidence: contextAnchor.distance == 1 ? 0.9 : 0.8,
                evidence: evidence(
                    sequence: contextAnchor.turn.sequence,
                    text: contextAnchor.turn.text
                )
            )
        )
    }

    private static func collectContextAnchors(
        _ request: DiscourseResolutionRequest
    ) -> ContextAnchorDecision {
        var anchors: [ContextAnchor] = []
        var constraints: [DiscourseResolutionConstraint] = []
        for turn in request.verifiedTurns {
            guard let distance = distance(from: turn.sequence, to: request.currentSequence) else {
                appendUnique(.staleContextIgnored, to: &constraints)
                continue
            }
            let blockers = TextSafety.blockingConstraints(in: turn.text)
            guard blockers.isEmpty else { return .abstain(blockers) }
            let turnAnchors = GenderAnchorScanner.scan(turn.text)
            if turnAnchors.contains(where: \.isPlural) {
                return .abstain([.pluralReferenceProtected])
            }
            anchors += turnAnchors.map {
                ContextAnchor(anchor: $0, turn: turn, distance: distance)
            }
        }
        return .anchors(anchors, constraints)
    }

    private static func hasValidOrder(_ request: DiscourseResolutionRequest) -> Bool {
        var sequences = Set<Int>()
        for turn in request.verifiedTurns {
            guard turn.sequence < request.currentSequence else { return false }
            guard sequences.insert(turn.sequence).inserted else { return false }
        }
        return true
    }

    private static func distance(from earlier: Int, to current: Int) -> Int? {
        let subtraction = current.subtractingReportingOverflow(earlier)
        guard !subtraction.overflow, (1...2).contains(subtraction.partialValue) else {
            return nil
        }
        return subtraction.partialValue
    }

    private static func ambiguity(for anchors: [GenderAnchor]) -> DiscourseAmbiguity? {
        guard anchors.count > 1 else { return nil }
        return Set(anchors.map(\.gender)).count == 1
            ? .multipleSameGenderAnchors
            : .competingGenderAnchors
    }

    private static func evidence(sequence: Int, text: String) -> DiscourseCorrectionEvidence {
        DiscourseCorrectionEvidence(sequence: sequence, text: text)
    }

    private static func appendUnique(
        _ value: DiscourseResolutionConstraint,
        to values: inout [DiscourseResolutionConstraint]
    ) {
        if !values.contains(value) { values.append(value) }
    }
}
