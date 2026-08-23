import Foundation

struct HyMT2ParsedPronounOutput: Equatable, Sendable {
    let cleanTarget: String
    let realizations: [HyMT2PronounRealization]
}

enum HyMT2PronounMarkerParser {
    static func parse(
        _ output: String,
        plan: HyMT2PronounPlan
    ) throws -> HyMT2ParsedPronounOutput {
        let tokens = try validatedTokens(in: output, plan: plan)
        let bindings = tokens.map { HyMT2PronounAnchorBinder.bind($0, in: output) }
        try validateUniquePronounRanges(bindings, occurrences: plan.occurrences)
        let realizations = try validateRealizations(bindings, occurrences: plan.occurrences)
        return HyMT2ParsedPronounOutput(
            cleanTarget: clean(output, tokens: tokens)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            realizations: realizations
        )
    }

    static func cleanTargetAfterSurfaceValidation(
        _ output: String,
        plan: HyMT2PronounPlan
    ) throws -> String {
        let tokens = try validatedTokens(in: output, plan: plan)
        return clean(output, tokens: tokens)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validatedTokens(
        in output: String,
        plan: HyMT2PronounPlan
    ) throws -> [HyMT2PronounAnchorToken] {
        let tokens = HyMT2PronounMarkerTokenizer.tokens(in: output)
        try HyMT2PronounMarkerTokenizer.validate(
            output,
            tokens: tokens,
            expected: plan.occurrences
        )
        try HyMT2PronounProtocolResidualValidator.validate(
            output,
            excluding: tokens.map(\.range),
            plan: plan
        )
        return tokens
    }

    private static func validateRealizations(
        _ bindings: [HyMT2PronounAnchorBinding],
        occurrences: [HyMT2PronounOccurrence]
    ) throws -> [HyMT2PronounRealization] {
        let byName = Dictionary(
            uniqueKeysWithValues: bindings.map {
                ($0.token.markerName, $0)
            })
        var realizations: [HyMT2PronounRealization] = []
        var issues: [OutputValidationIssue] = []
        for occurrence in occurrences {
            guard let binding = byName[occurrence.markerName] else { continue }
            let classification =
                binding.isStructurallyValid
                ? HyMT2PronounRealizationClassifier.acceptedClass(
                    binding.observedClass,
                    for: occurrence.resolution
                )
                : nil
            if let classification {
                realizations.append(
                    HyMT2PronounRealization(
                        occurrence: occurrence,
                        realizationClass: classification
                    )
                )
            } else {
                issues.append(
                    .wrongPronounRealization(
                        occurrence.identifier,
                        occurrence.sourceRange,
                        occurrence.resolution,
                        binding.observedClass
                    )
                )
            }
        }
        guard issues.isEmpty else { throw OutputValidationFailure(issues: issues) }
        return realizations
    }

    private static func validateUniquePronounRanges(
        _ bindings: [HyMT2PronounAnchorBinding],
        occurrences: [HyMT2PronounOccurrence]
    ) throws {
        var used: [Range<String.Index>] = []
        for binding in bindings {
            guard let range = binding.pronounRange else { continue }
            guard !used.contains(where: { $0.overlaps(range) }) else {
                let identifier =
                    occurrences.first {
                        $0.markerName == binding.token.markerName
                    }?.identifier ?? "unknown"
                throw failure(.reusedPronounRealization(identifier))
            }
            used.append(range)
        }
    }

    private static func clean(
        _ output: String,
        tokens: [HyMT2PronounAnchorToken]
    ) -> String {
        var result = ""
        var cursor = output.startIndex
        for token in tokens {
            result += output[cursor..<token.range.lowerBound]
            cursor = token.range.upperBound
        }
        result += output[cursor...]
        return result
    }

    private static func failure(_ issue: OutputValidationIssue) -> OutputValidationFailure {
        OutputValidationFailure(issues: [issue])
    }
}
