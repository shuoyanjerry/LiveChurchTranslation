import TranslationAPI
@testable import TranslationHyMT2

enum HyMT2SchemaShadowSemanticOracle {
    static func validate(
        target: String,
        carrier: String,
        tokens: [String: String],
        bindings: [String: HyMT2SchemaShadowBinding],
        plan: HyMT2SchemaShadowPlan
    ) throws {
        guard bindings.count == plan.occurrences.count,
            tokens.count == plan.occurrences.count
        else {
            throw HyMT2SchemaShadowFailureCode.semanticOccurrence
        }
        for occurrence in plan.occurrences {
            guard let token = tokens[occurrence.identifier],
                carrier.ranges(of: token).count == 1,
                let binding = bindings[occurrence.identifier]
            else {
                throw HyMT2SchemaShadowFailureCode.semanticOccurrence
            }
            try validateSurface(binding.surface, occurrence: occurrence)
            let context = clauseContext(around: token, in: carrier)
            guard containsAny(occurrence.anchorAlternatives, in: context) else {
                throw HyMT2SchemaShadowFailureCode.semanticAnchor
            }
        }
        let normalizedTarget = target.lowercased()
        guard plan.globalAnchorGroups.allSatisfy({ containsAny($0, in: normalizedTarget) }) else {
            throw HyMT2SchemaShadowFailureCode.semanticAnchor
        }
    }

    private static func validateSurface(
        _ surface: String,
        occurrence: HyMT2SchemaShadowOccurrence
    ) throws {
        let normalized = surface.lowercased()
        guard occurrence.expectedSurfaces.contains(normalized) else {
            throw HyMT2SchemaShadowFailureCode.semanticSurface
        }
        guard let resolution = occurrence.resolution else { return }
        let observed = HyMT2PronounRealizationClassifier.observe(normalized)
        guard HyMT2PronounRealizationClassifier.acceptedClass(observed, for: resolution) != nil else {
            throw HyMT2SchemaShadowFailureCode.semanticSurface
        }
    }

    private static let clauseSeparators: Set<Character> = [
        ".", ",", ";", "!", "?", "\n",
    ]

    private static func clauseContext(around token: String, in value: String) -> String {
        guard let tokenRange = value.range(of: token) else { return "" }
        var lower = tokenRange.lowerBound
        while lower > value.startIndex {
            let previous = value.index(before: lower)
            if clauseSeparators.contains(value[previous]) { break }
            lower = previous
        }
        var upper = tokenRange.upperBound
        while upper < value.endIndex {
            if clauseSeparators.contains(value[upper]) { break }
            upper = value.index(after: upper)
        }
        return String(value[lower..<upper]).lowercased()
    }

    private static func containsAny(_ alternatives: [String], in value: String) -> Bool {
        alternatives.contains { value.localizedCaseInsensitiveContains($0) }
    }
}

extension String {
    fileprivate func ranges(of needle: String) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var cursor = startIndex
        while cursor < endIndex {
            guard let range = range(of: needle, range: cursor..<endIndex) else { break }
            result.append(range)
            cursor = range.upperBound
        }
        return result
    }
}
