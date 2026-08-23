import Foundation

struct HyMT2SpacedCanonicalBinding {
    let token: HyMT2PronounAnchorToken
    let pronounRange: Range<String.Index>
    let removalRange: Range<String.Index>
    let envelopeRange: Range<String.Index>
    let rightShape: HyMT2SpacedCanonicalRightShape
    let observedClass: HyMT2ObservedPronounClass
}

enum HyMT2SpacedCanonicalRightShape {
    case lexicalContinuation
    case commaContinuation
    case terminalPeriod
    case terminalEnd
}

enum HyMT2SpacedCanonicalPronounParser {
    static func hasCandidate(
        _ tokens: [HyMT2PronounAnchorToken],
        in output: String
    ) -> Bool {
        tokens.contains { token in
            guard token.range.lowerBound > output.startIndex else { return false }
            return output[output.index(before: token.range.lowerBound)] == " "
        }
    }

    static func parse(
        _ output: String,
        plan: HyMT2PronounPlan,
        tokens: [HyMT2PronounAnchorToken]
    ) throws -> HyMT2ParsedPronounOutput {
        try HyMT2PronounMarkerTokenizer.validate(
            output,
            tokens: tokens,
            expected: plan.occurrences
        )
        let bindings = try tokens.enumerated().map { index, token in
            try binding(
                token,
                isLastToken: index == tokens.index(before: tokens.endIndex),
                in: output
            )
        }
        try validateIndependent(bindings)
        try HyMT2PronounProtocolResidualValidator.validate(
            output,
            excluding: tokens.map(\.range),
            plan: plan
        )
        let realizations = try validateRealizations(
            bindings,
            occurrences: plan.occurrences
        )
        return HyMT2ParsedPronounOutput(
            cleanTarget: try clean(output, bindings: bindings)
                .trimmingCharacters(in: .whitespacesAndNewlines),
            realizations: realizations
        )
    }
}

extension HyMT2SpacedCanonicalPronounParser {
    private static func binding(
        _ token: HyMT2PronounAnchorToken,
        isLastToken: Bool,
        in output: String
    ) throws -> HyMT2SpacedCanonicalBinding {
        guard token.range.lowerBound > output.startIndex else { throw malformedFailure() }
        let preSpace = output.index(before: token.range.lowerBound)
        guard output[preSpace] == " ",
            let pronounRange = asciiWordEnding(at: preSpace, in: output),
            HyMT2PronounTokenBoundary.hasComplete(pronounRange, in: output)
        else { throw malformedFailure() }
        let observed = HyMT2PronounRealizationClassifier.observe(String(output[pronounRange]))
        guard isAllowedPronoun(observed) else { throw malformedFailure() }
        let rightEnvelope = try HyMT2SpacedCanonicalRightEnvelopeParser.envelope(
            after: token.range.upperBound,
            isLastToken: isLastToken,
            in: output
        )
        return HyMT2SpacedCanonicalBinding(
            token: token,
            pronounRange: pronounRange,
            removalRange: pronounRange.upperBound..<token.range.upperBound,
            envelopeRange: pronounRange.lowerBound..<rightEnvelope.end,
            rightShape: rightEnvelope.shape,
            observedClass: observed
        )
    }

    private static func asciiWordEnding(
        at end: String.Index,
        in output: String
    ) -> Range<String.Index>? {
        var start = end
        while start > output.startIndex {
            let previous = output.index(before: start)
            guard HyMT2PronounTokenBoundary.isASCIILetter(output[previous]) else { break }
            start = previous
        }
        return start == end ? nil : start..<end
    }

    private static func isAllowedPronoun(_ value: HyMT2ObservedPronounClass) -> Bool {
        value == .female || value == .male || value == .singularThey
    }

    private static func validateIndependent(
        _ bindings: [HyMT2SpacedCanonicalBinding]
    ) throws {
        var previous: HyMT2SpacedCanonicalBinding?
        for binding in bindings {
            if let previous {
                guard !previous.envelopeRange.overlaps(binding.envelopeRange),
                    binding.pronounRange.lowerBound >= previous.token.range.upperBound
                else { throw malformedFailure() }
            }
            previous = binding
        }
    }

    private static func malformedFailure() -> OutputValidationFailure {
        OutputValidationFailure(issues: [.malformedPronounMarker])
    }
}
