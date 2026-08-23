enum HyMT2NegationShadowOutcome: Equatable, Sendable {
    case passed
    case failed(HyMT2NegationShadowFailureCategory)

    var code: String {
        switch self {
        case .passed: "neg.shadow.pass"
        case .failed(let category): "neg.shadow." + category.rawValue
        }
    }
}

struct HyMT2NegationShadowAssessment: Equatable, Sendable {
    let encoding: HyMT2NegationShadowEncoding
    let occurrenceCount: Int
    let outcome: HyMT2NegationShadowOutcome

    static func evaluate(
        _ output: String,
        plan: HyMT2NegationShadowPlan
    ) -> HyMT2NegationShadowAssessment {
        let outcome: HyMT2NegationShadowOutcome
        do {
            _ = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)
            outcome = .passed
        } catch let failure as HyMT2NegationShadowFailure {
            outcome = .failed(failure.category)
        } catch {
            outcome = .failed(.unexpectedError)
        }
        return HyMT2NegationShadowAssessment(
            encoding: plan.encoding,
            occurrenceCount: plan.occurrences.count,
            outcome: outcome
        )
    }
}
