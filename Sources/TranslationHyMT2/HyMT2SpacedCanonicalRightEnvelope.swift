struct HyMT2SpacedCanonicalRightEnvelope {
    let end: String.Index
    let shape: HyMT2SpacedCanonicalRightShape
}

enum HyMT2SpacedCanonicalRightEnvelopeParser {
    static func envelope(
        after blockEnd: String.Index,
        isLastToken: Bool,
        in output: String
    ) throws -> HyMT2SpacedCanonicalRightEnvelope {
        if blockEnd == output.endIndex {
            guard isLastToken else { throw malformedFailure() }
            return HyMT2SpacedCanonicalRightEnvelope(
                end: output.endIndex,
                shape: .terminalEnd
            )
        }
        if output[blockEnd] == "." {
            return try terminalPeriod(after: blockEnd, isLastToken: isLastToken, in: output)
        }
        if output[blockEnd] == "," {
            return try commaContinuation(after: blockEnd, in: output)
        }
        return try lexicalContinuation(after: blockEnd, in: output)
    }

    private static func terminalPeriod(
        after blockEnd: String.Index,
        isLastToken: Bool,
        in output: String
    ) throws -> HyMT2SpacedCanonicalRightEnvelope {
        let punctuationEnd = output.index(after: blockEnd)
        guard isLastToken, punctuationEnd == output.endIndex else {
            throw malformedFailure()
        }
        return HyMT2SpacedCanonicalRightEnvelope(
            end: punctuationEnd,
            shape: .terminalPeriod
        )
    }

    private static func commaContinuation(
        after blockEnd: String.Index,
        in output: String
    ) throws -> HyMT2SpacedCanonicalRightEnvelope {
        let space = output.index(after: blockEnd)
        guard space < output.endIndex, output[space] == " " else {
            throw malformedFailure()
        }
        let continuation = output.index(after: space)
        guard continuation < output.endIndex,
            HyMT2PronounTokenBoundary.isASCIILetter(output[continuation])
        else { throw malformedFailure() }
        return HyMT2SpacedCanonicalRightEnvelope(
            end: continuation,
            shape: .commaContinuation
        )
    }

    private static func lexicalContinuation(
        after blockEnd: String.Index,
        in output: String
    ) throws -> HyMT2SpacedCanonicalRightEnvelope {
        guard output[blockEnd] == " " else { throw malformedFailure() }
        let continuation = output.index(after: blockEnd)
        guard continuation < output.endIndex,
            isAllowedContinuation(output[continuation])
        else { throw malformedFailure() }
        return HyMT2SpacedCanonicalRightEnvelope(
            end: continuation,
            shape: .lexicalContinuation
        )
    }

    private static func isAllowedContinuation(_ value: Character) -> Bool {
        !value.isWhitespace
            && !value.isPunctuation
            && !value.unicodeScalars.contains { scalar in
                scalar.properties.generalCategory == .format
            }
    }

    private static func malformedFailure() -> OutputValidationFailure {
        OutputValidationFailure(issues: [.malformedPronounMarker])
    }
}
