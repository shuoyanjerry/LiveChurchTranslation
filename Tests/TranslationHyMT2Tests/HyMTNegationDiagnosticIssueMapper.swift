@testable import TranslationHyMT2

enum HyMTNegationDiagnosticIssueMapper {
    static func codes(
        _ issues: [OutputValidationIssue]
    ) -> [HyMTNegationDiagnosticIssueCode] {
        let values = Set(issues.map(code))
        return HyMTNegationDiagnosticIssueCode.allCases.filter(values.contains)
    }

    private static func code(
        _ issue: OutputValidationIssue
    ) -> HyMTNegationDiagnosticIssueCode {
        switch issue {
        case .empty, .implausibleLength, .metaText, .promptControlDelimiter:
            basicCode(issue)
        case .unexpectedSourceScript, .missingTerm, .missingNumber, .missingNegation,
            .malformedScriptureReference:
            fidelityCode(issue)
        case .negativePronounSourceRange,
            .emptyPronounSourceRange,
            .pronounSourceRangeOutOfBounds,
            .pronounSourceRangeNotOnCharacterBoundary,
            .duplicatePronounSourceRange,
            .overlappingPronounSourceRanges,
            .pronounSourceRangeWrongGlyph,
            .tooManyPronounOccurrences,
            .reservedPronounMarkerCollision,
            .missingPronounMarker,
            .duplicatePronounMarker,
            .unknownPronounMarker,
            .malformedPronounMarker,
            .pronounMarkerResolutionMismatch,
            .reusedPronounRealization,
            .wrongPronounRealization:
            .pronounProtocol
        }
    }

    private static func basicCode(
        _ issue: OutputValidationIssue
    ) -> HyMTNegationDiagnosticIssueCode {
        switch issue {
        case .empty: .empty
        case .implausibleLength: .implausibleLength
        case .metaText: .metaText
        case .promptControlDelimiter: .promptControl
        default: preconditionFailure("Unexpected basic diagnostic issue.")
        }
    }

    private static func fidelityCode(
        _ issue: OutputValidationIssue
    ) -> HyMTNegationDiagnosticIssueCode {
        switch issue {
        case .unexpectedSourceScript: .sourceScript
        case .missingTerm: .missingTerm
        case .missingNumber: .missingNumber
        case .missingNegation: .missingNegation
        case .malformedScriptureReference: .scriptureReference
        default: preconditionFailure("Unexpected fidelity diagnostic issue.")
        }
    }
}
