import Foundation

struct HyMT2PronounAnchorToken {
    let markerName: String
    let resolutionToken: String
    let range: Range<String.Index>
}

enum HyMT2PronounMarkerTokenizer {
    static func tokens(in output: String) -> [HyMT2PronounAnchorToken] {
        guard let expression = try? NSRegularExpression(pattern: protectedBlockPattern) else {
            return []
        }
        let fullRange = NSRange(output.startIndex..., in: output)
        return expression.matches(in: output, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: output),
                let nameRange = Range(match.range(at: 1), in: output),
                let resolutionRange = Range(match.range(at: 2), in: output),
                let closingNameRange = Range(match.range(at: 3), in: output),
                output[nameRange] == output[closingNameRange]
            else { return nil }
            return HyMT2PronounAnchorToken(
                markerName: String(output[nameRange]),
                resolutionToken: String(output[resolutionRange]),
                range: range
            )
        }
    }

    static func validate(
        _ output: String,
        tokens: [HyMT2PronounAnchorToken],
        expected: [HyMT2PronounOccurrence]
    ) throws {
        try validateSurface(output, tokens: tokens)
        try validateCounts(tokens, expected: expected)
    }

    private static let protectedBlockPattern =
        #"<QLR_([A-F0-9]{12}_P[0-9]{4})>"#
        + #"(QLR_(?:UNRESOLVED|VERIFIED_FEMALE|VERIFIED_MALE|VERIFIED_DEITY))"#
        + #"</QLR_([A-F0-9]{12}_P[0-9]{4})>"#

    private static func validateSurface(
        _ output: String,
        tokens: [HyMT2PronounAnchorToken]
    ) throws {
        var cursor = output.startIndex
        var remainder = ""
        for token in tokens {
            remainder += output[cursor..<token.range.lowerBound]
            cursor = token.range.upperBound
        }
        remainder += output[cursor...]
        guard !HyMT2ReservedProtocolText.containsPrefix(in: remainder) else {
            throw failure(.malformedPronounMarker)
        }
    }

    private static func validateCounts(
        _ tokens: [HyMT2PronounAnchorToken],
        expected: [HyMT2PronounOccurrence]
    ) throws {
        let expectedNames = Set(expected.map(\.markerName))
        if let unknown = tokens.first(where: { !expectedNames.contains($0.markerName) }) {
            let ordinal =
                unknown.markerName.split(separator: "_").last.map(String.init)
                ?? "unknown"
            throw failure(.unknownPronounMarker(ordinal))
        }
        for occurrence in expected {
            let markerCount = tokens.lazy.filter { $0.markerName == occurrence.markerName }.count
            if markerCount > 1 {
                throw failure(.duplicatePronounMarker(occurrence.identifier))
            }
            if markerCount == 0 {
                throw failure(
                    .missingPronounMarker(
                        occurrence.identifier,
                        occurrence.sourceRange,
                        occurrence.resolution
                    )
                )
            }
            guard let token = tokens.first(where: { $0.markerName == occurrence.markerName }) else {
                continue
            }
            let expectedToken = HyMT2PronounResolutionToken.value(for: occurrence.resolution)
            if token.resolutionToken != expectedToken {
                throw failure(.pronounMarkerResolutionMismatch(occurrence.identifier))
            }
        }
    }

    private static func failure(_ issue: OutputValidationIssue) -> OutputValidationFailure {
        OutputValidationFailure(issues: [issue])
    }
}
