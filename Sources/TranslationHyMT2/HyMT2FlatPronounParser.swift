import Foundation

enum HyMT2FlatPronounParser {
    static func parse(
        _ output: String,
        plan: HyMT2PronounPlan,
        tokens: [HyMT2FlatPronounToken]
    ) throws -> HyMT2ParsedPronounOutput {
        try HyMT2FlatPronounTokenizer.validateSurface(output, tokens: tokens)
        try validateUniquePronounRanges(tokens)
        try validateCounts(tokens, occurrences: plan.occurrences)
        let realizations = try validateRealizations(
            tokens,
            output: output,
            occurrences: plan.occurrences
        )
        return HyMT2ParsedPronounOutput(
            cleanTarget: clean(output, tokens: tokens)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            realizations: realizations
        )
    }

    private static func validateUniquePronounRanges(
        _ tokens: [HyMT2FlatPronounToken]
    ) throws {
        var used: [Range<String.Index>] = []
        for token in tokens {
            guard !used.contains(where: { $0.overlaps(token.pronounRange) }) else {
                throw failure(.reusedPronounRealization(token.identifier))
            }
            used.append(token.pronounRange)
        }
    }

    private static func validateCounts(
        _ tokens: [HyMT2FlatPronounToken],
        occurrences: [HyMT2PronounOccurrence]
    ) throws {
        let expectedIdentifiers = Set(occurrences.map(\.identifier))
        if let unknown = tokens.first(where: {
            !expectedIdentifiers.contains($0.identifier)
        }) {
            throw failure(.unknownPronounMarker(unknown.identifier))
        }
        for occurrence in occurrences {
            let matching = tokens.filter { $0.identifier == occurrence.identifier }
            if matching.count > 1 {
                throw failure(.duplicatePronounMarker(occurrence.identifier))
            }
            guard let token = matching.first else {
                throw failure(
                    .missingPronounMarker(
                        occurrence.identifier,
                        occurrence.sourceRange,
                        occurrence.resolution
                    )
                )
            }
            let expected = HyMT2PronounResolutionToken.value(for: occurrence.resolution)
            guard token.resolutionToken == expected else {
                throw failure(.pronounMarkerResolutionMismatch(occurrence.identifier))
            }
        }
    }

    private static func validateRealizations(
        _ tokens: [HyMT2FlatPronounToken],
        output: String,
        occurrences: [HyMT2PronounOccurrence]
    ) throws -> [HyMT2PronounRealization] {
        let byIdentifier = Dictionary(
            uniqueKeysWithValues: tokens.map { ($0.identifier, $0) }
        )
        var realizations: [HyMT2PronounRealization] = []
        var issues: [OutputValidationIssue] = []
        for occurrence in occurrences {
            guard let token = byIdentifier[occurrence.identifier] else { continue }
            let observed = HyMT2PronounRealizationClassifier.observe(
                String(output[token.pronounRange])
            )
            if let accepted = HyMT2PronounRealizationClassifier.acceptedClass(
                observed,
                for: occurrence.resolution
            ) {
                realizations.append(
                    HyMT2PronounRealization(
                        occurrence: occurrence,
                        realizationClass: accepted
                    )
                )
            } else {
                issues.append(
                    .wrongPronounRealization(
                        occurrence.identifier,
                        occurrence.sourceRange,
                        occurrence.resolution,
                        observed
                    )
                )
            }
        }
        guard issues.isEmpty else { throw OutputValidationFailure(issues: issues) }
        return realizations
    }

    private static func clean(
        _ output: String,
        tokens: [HyMT2FlatPronounToken]
    ) -> String {
        var result = ""
        var cursor = output.startIndex
        for token in tokens {
            result += output[cursor..<token.removableRange.lowerBound]
            cursor = token.removableRange.upperBound
        }
        result += output[cursor...]
        return result
    }

    private static func failure(_ issue: OutputValidationIssue) -> OutputValidationFailure {
        OutputValidationFailure(issues: [issue])
    }
}
