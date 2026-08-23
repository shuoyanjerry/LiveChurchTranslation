import Foundation

struct HyMT2PronounAnchorBinding {
    let token: HyMT2PronounAnchorToken
    let pronounRange: Range<String.Index>?
    let observedClass: HyMT2ObservedPronounClass
    let isStructurallyValid: Bool
}

enum HyMT2PronounAnchorBinder {
    static func bind(
        _ token: HyMT2PronounAnchorToken,
        in output: String
    ) -> HyMT2PronounAnchorBinding {
        let whitespace = whitespaceBefore(token.range.lowerBound, in: output)
        let tokenEnd = whitespace.lowerBound
        let pronounRange = asciiWordEnding(at: tokenEnd, in: output)
        let tokenBoundaryIsValid = HyMT2PronounTokenBoundary.hasComplete(
            pronounRange,
            in: output
        )
        let observed = observedClass(
            pronounRange: tokenBoundaryIsValid ? pronounRange : nil,
            endingAt: tokenEnd,
            in: output
        )
        let spacingIsValid = whitespace.isEmpty
        let rightBoundaryIsValid = HyMT2PronounTokenBoundary.hasAllowedRight(
            after: token.range.upperBound,
            in: output
        )
        let structureIsValid =
            spacingIsValid
            && tokenBoundaryIsValid
            && rightBoundaryIsValid
        return HyMT2PronounAnchorBinding(
            token: token,
            pronounRange: pronounRange,
            observedClass: diagnosticClass(
                observed,
                envelopeIsValid: spacingIsValid && rightBoundaryIsValid
            ),
            isStructurallyValid: structureIsValid
        )
    }

    private static func diagnosticClass(
        _ observed: HyMT2ObservedPronounClass,
        envelopeIsValid: Bool
    ) -> HyMT2ObservedPronounClass {
        guard !envelopeIsValid else { return observed }
        switch observed {
        case .female, .male, .singularThey:
            return .other
        default:
            return observed
        }
    }

    private static func whitespaceBefore(
        _ end: String.Index,
        in output: String
    ) -> Range<String.Index> {
        var start = end
        while start > output.startIndex {
            let previous = output.index(before: start)
            guard output[previous].isWhitespace else { break }
            start = previous
        }
        return start..<end
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

    private static func observedClass(
        pronounRange: Range<String.Index>?,
        endingAt end: String.Index,
        in output: String
    ) -> HyMT2ObservedPronounClass {
        if let pronounRange {
            return HyMT2PronounRealizationClassifier.observe(String(output[pronounRange]))
        }
        return HyMT2PronounRealizationClassifier.observe(
            String(output[trailingUnit(endingAt: end, in: output)])
        )
    }

    private static func trailingUnit(
        endingAt end: String.Index,
        in output: String
    ) -> Range<String.Index> {
        var start = end
        while start > output.startIndex {
            let previous = output.index(before: start)
            guard !output[previous].isWhitespace else { break }
            start = previous
        }
        return start..<end
    }

}
