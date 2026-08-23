import DiscourseResolutionAPI

extension EvidenceSelector {
    static func inspectHumanContext(
        _ request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        switch validatedContext(request) {
        case .abstain(let blockers):
            return .abstain([], blockers)
        case .anchors(let anchors, let constraints):
            if let ambiguity = ambiguity(for: anchors.map(\.anchor)) {
                return .abstain([ambiguity], constraints)
            }
            return .abstain([.noExplicitGenderAnchor], constraints)
        }
    }

    static func selectDeityFromContext(
        _ request: DiscourseResolutionRequest
    ) -> EvidenceDecision {
        switch validatedContext(request) {
        case .abstain(let blockers):
            return .abstain([], blockers)
        case .anchors(let anchors, let constraints):
            if let ambiguity = ambiguity(for: anchors.map(\.anchor)) {
                return .abstain([ambiguity], constraints)
            }
            guard let context = anchors.first, context.anchor.referent == .deity else {
                return .abstain([.noExplicitDeityAnchor], constraints)
            }
            return selectedDeityContextEvidence(context)
        }
    }

    private static func validatedContext(
        _ request: DiscourseResolutionRequest
    ) -> ContextAnchorDecision {
        guard request.verifiedTurns.count <= 2 else {
            return .abstain([.contextLimitExceeded])
        }
        guard hasValidOrder(request) else {
            return .abstain([.outOfOrderContext])
        }
        return collectContextAnchors(request)
    }

    private static func selectedDeityContextEvidence(
        _ context: ContextAnchor
    ) -> EvidenceDecision {
        .evidence(
            SelectedEvidence(
                referent: .deity,
                reason: .uniqueRecentDeityAnchor,
                confidence: context.distance == 1 ? 0.9 : 0.8,
                evidence: evidence(
                    sequence: context.turn.sequence,
                    text: context.turn.text
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
            let found = ReferentAnchorScanner.scan(turn.text)
            if found.contains(where: \.isPlural) {
                return .abstain([.pluralReferenceProtected])
            }
            anchors += found.map {
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

    private static func appendUnique(
        _ value: DiscourseResolutionConstraint,
        to values: inout [DiscourseResolutionConstraint]
    ) {
        if !values.contains(value) { values.append(value) }
    }
}
