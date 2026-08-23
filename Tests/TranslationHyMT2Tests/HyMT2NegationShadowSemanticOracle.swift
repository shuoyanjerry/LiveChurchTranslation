import Foundation

enum HyMT2NegationShadowSemanticFailure: Error, Equatable {
    case anchorMissing
    case occurrenceMismatch
}

enum HyMT2NegationShadowSemanticOracle {
    static func validate(
        rawOutput: String,
        parsed: HyMT2ParsedNegationShadow,
        plan: HyMT2NegationShadowPlan,
        fixture: HyMT2NegationShadowQ4Fixture
    ) throws {
        guard fixture.occurrenceAnchorAlternatives.count == plan.occurrences.count,
            parsed.bindings.count == plan.occurrences.count
        else {
            throw HyMT2NegationShadowSemanticFailure.occurrenceMismatch
        }
        for (occurrence, anchors) in zip(
            plan.occurrences,
            fixture.occurrenceAnchorAlternatives
        ) {
            guard let markerRange = rawOutput.range(of: occurrence.protectedBlock) else {
                throw HyMT2NegationShadowSemanticFailure.occurrenceMismatch
            }
            let context = clauseContext(around: markerRange, in: rawOutput)
            guard containsAny(anchors, in: context) else {
                throw HyMT2NegationShadowSemanticFailure.anchorMissing
            }
        }
        let target = parsed.cleanTarget.lowercased()
        guard fixture.globalAnchorGroups.allSatisfy({ containsAny($0, in: target) }) else {
            throw HyMT2NegationShadowSemanticFailure.anchorMissing
        }
    }

    private static let clauseSeparators: Set<Character> = [
        ".", ",", ";", "!", "?", "\n",
    ]

    private static func clauseContext(
        around marker: Range<String.Index>,
        in output: String
    ) -> String {
        var lower = marker.lowerBound
        while lower > output.startIndex {
            let previous = output.index(before: lower)
            if clauseSeparators.contains(output[previous]) { break }
            lower = previous
        }
        var upper = marker.upperBound
        while upper < output.endIndex {
            if clauseSeparators.contains(output[upper]) { break }
            upper = output.index(after: upper)
        }
        return String(output[lower..<upper]).lowercased()
    }

    private static func containsAny(
        _ alternatives: [String],
        in value: String
    ) -> Bool {
        alternatives.contains(where: value.localizedCaseInsensitiveContains)
    }
}
