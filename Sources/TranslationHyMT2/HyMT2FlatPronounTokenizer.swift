import Foundation

struct HyMT2FlatPronounToken {
    let identifier: String
    let resolutionToken: String
    let pronounRange: Range<String.Index>
    let range: Range<String.Index>

    var removableRange: Range<String.Index> {
        pronounRange.upperBound..<range.upperBound
    }
}

enum HyMT2FlatPronounTokenizer {
    static func tokens(in output: String) -> [HyMT2FlatPronounToken] {
        guard let expression = try? NSRegularExpression(pattern: flatPattern) else {
            return []
        }
        let fullRange = NSRange(output.startIndex..., in: output)
        return expression.matches(in: output, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: output),
                let pronounRange = Range(match.range(at: 1), in: output),
                let identifierRange = Range(match.range(at: 2), in: output),
                let resolutionRange = Range(match.range(at: 3), in: output)
            else { return nil }
            return HyMT2FlatPronounToken(
                identifier: String(output[identifierRange]),
                resolutionToken: String(output[resolutionRange]),
                pronounRange: pronounRange,
                range: range
            )
        }
    }

    static func validateSurface(
        _ output: String,
        tokens: [HyMT2FlatPronounToken]
    ) throws {
        try validateBoundaries(tokens, in: output)
        let remainder = outputRemoving(tokens.map(\.range), from: output)
        let inspection = HyMT2ReservedProtocolText.inspectionForm(remainder)
        guard !HyMT2ReservedProtocolText.containsPrefix(in: remainder),
            !containsResidualIdentifier(in: inspection)
        else { throw malformedFailure() }
    }

    static func validateNoResidualIdentifiers(
        in output: String,
        excluding ranges: [Range<String.Index>]
    ) throws {
        let remainder = outputRemoving(ranges, from: output)
        let inspection = HyMT2ReservedProtocolText.inspectionForm(remainder)
        guard !containsResidualIdentifier(in: inspection) else {
            throw malformedFailure()
        }
    }

    private static let flatPattern =
        #"([A-Za-z]+) (P[0-9]{4}) "#
        + #"(QLR_(?:UNRESOLVED|VERIFIED_FEMALE|VERIFIED_MALE|VERIFIED_DEITY))"#

    private static func validateBoundaries(
        _ tokens: [HyMT2FlatPronounToken],
        in output: String
    ) throws {
        for token in tokens {
            guard HyMT2PronounTokenBoundary.hasComplete(token.pronounRange, in: output),
                HyMT2PronounTokenBoundary.hasAllowedRight(
                    after: token.range.upperBound,
                    in: output
                )
            else { throw malformedFailure() }
        }
    }

    private static func outputRemoving(
        _ ranges: [Range<String.Index>],
        from output: String
    ) -> String {
        var result = ""
        var cursor = output.startIndex
        for range in ranges {
            result += output[cursor..<range.lowerBound]
            cursor = range.upperBound
        }
        result += output[cursor...]
        return result
    }

    private static func containsResidualIdentifier(in output: String) -> Bool {
        guard
            let expression = try? NSRegularExpression(
                pattern: #"P[0-9]{4}"#,
                options: .caseInsensitive
            )
        else { return true }
        return expression.firstMatch(
            in: output,
            range: NSRange(output.startIndex..., in: output)
        ) != nil
    }

    private static func malformedFailure() -> OutputValidationFailure {
        OutputValidationFailure(issues: [.malformedPronounMarker])
    }
}
