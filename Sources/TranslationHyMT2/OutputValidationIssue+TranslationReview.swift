extension OutputValidationIssue {
    var translationReviewCode: String? {
        switch self {
        case .empty, .promptControlDelimiter:
            nil
        case .implausibleLength:
            "quality.implausible_length"
        case .contextReplay:
            "quality.context_replay"
        case .metaText:
            "quality.meta_text"
        case .unexpectedSourceScript:
            "quality.unexpected_script"
        case .missingTerm:
            "quality.missing_required_term"
        case .missingNumber:
            "quality.missing_number"
        case .missingNegation:
            "quality.missing_negation"
        case .malformedScriptureReference:
            "quality.scripture_reference"
        case .wrongPronounRealization, .reusedPronounRealization,
            .pronounAlternativeList:
            "quality.pronoun_alignment"
        case .negativePronounSourceRange, .emptyPronounSourceRange,
            .pronounSourceRangeOutOfBounds, .pronounSourceRangeNotOnCharacterBoundary,
            .duplicatePronounSourceRange, .overlappingPronounSourceRanges,
            .pronounSourceRangeWrongGlyph, .tooManyPronounOccurrences,
            .reservedPronounMarkerCollision, .missingPronounMarker,
            .duplicatePronounMarker, .unknownPronounMarker, .malformedPronounMarker,
            .pronounMarkerOrderMismatch, .pronounMarkerResolutionMismatch:
            "quality.pronoun_protocol"
        }
    }
}
