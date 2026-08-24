import TranslationAPI

enum OutputValidationIssue: Equatable, Sendable {
    case empty
    case implausibleLength
    case contextReplay
    case metaText
    case promptControlDelimiter
    case unexpectedSourceScript
    case missingTerm(String)
    case missingNumber(String)
    case missingNegation
    case malformedScriptureReference
    case negativePronounSourceRange(Int, Int)
    case emptyPronounSourceRange(Int)
    case pronounSourceRangeOutOfBounds(Int, Int)
    case pronounSourceRangeNotOnCharacterBoundary(Int, Int)
    case duplicatePronounSourceRange(Int, Int)
    case overlappingPronounSourceRanges(Int, Int)
    case pronounSourceRangeWrongGlyph(Int)
    case tooManyPronounOccurrences(Int)
    case reservedPronounMarkerCollision(String)
    case missingPronounMarker(
        String,
        TranslationSourceRange,
        TranslationPronounResolution
    )
    case duplicatePronounMarker(String)
    case unknownPronounMarker(String)
    case malformedPronounMarker
    case pronounMarkerOrderMismatch
    case pronounMarkerResolutionMismatch(String)
    case pronounAlternativeList
    case reusedPronounRealization(String)
    case wrongPronounRealization(
        String,
        TranslationSourceRange,
        TranslationPronounResolution,
        HyMT2ObservedPronounClass
    )

    var description: String {
        switch self {
        case .empty: "empty output"
        case .implausibleLength: "implausible output length"
        case .contextReplay: "recent translation context was replayed"
        case .metaText: "model commentary or instruction text"
        case .promptControlDelimiter: "prompt-control delimiter remains in output"
        case .unexpectedSourceScript: "output script does not match the target language"
        case .missingTerm(let term): "missing required term: \(term)"
        case .missingNumber(let number): "missing number: \(number)"
        case .missingNegation: "source negation was not preserved"
        case .malformedScriptureReference: "Scripture reference was not preserved"
        case .negativePronounSourceRange(let location, let length):
            "pronoun source range is negative: \(location), \(length)"
        case .emptyPronounSourceRange(let location):
            "pronoun source range is empty at UTF-16 location \(location)"
        case .pronounSourceRangeOutOfBounds(let location, let length):
            "pronoun source range is out of bounds: \(location), \(length)"
        case .pronounSourceRangeNotOnCharacterBoundary(let location, let length):
            "pronoun source range splits a character: \(location), \(length)"
        case .duplicatePronounSourceRange(let location, let length):
            "duplicate pronoun source range: \(location), \(length)"
        case .overlappingPronounSourceRanges(let first, let second):
            "pronoun source ranges overlap at UTF-16 locations \(first) and \(second)"
        case .pronounSourceRangeWrongGlyph(let location):
            "pronoun source range does not cover exactly one 他/她/祂 glyph at \(location)"
        case .tooManyPronounOccurrences(let count):
            "pronoun occurrence count exceeds marker capacity: \(count)"
        case .reservedPronounMarkerCollision(let field):
            "reserved pronoun marker prefix appears in \(field)"
        case .missingPronounMarker(let identifier, _, let expected):
            diagnosticDescription(identifier, expected: expected, observed: .missing)
        case .duplicatePronounMarker(let identifier):
            "duplicate pronoun marker: \(identifier)"
        case .unknownPronounMarker(let identifier):
            "unknown pronoun marker: \(identifier)"
        case .malformedPronounMarker:
            "malformed or incomplete pronoun marker"
        case .pronounMarkerOrderMismatch:
            "pronoun markers changed source occurrence order"
        case .pronounMarkerResolutionMismatch(let identifier):
            "pronoun marker \(identifier) changed its encoded resolution"
        case .pronounAlternativeList:
            "model emitted a pronoun alternative list"
        case .reusedPronounRealization(let identifier):
            "pronoun marker \(identifier) reuses another pronoun token"
        case .wrongPronounRealization(let identifier, _, let expected, let observed):
            diagnosticDescription(identifier, expected: expected, observed: observed)
        }
    }

    private func diagnosticDescription(
        _ identifier: String,
        expected: TranslationPronounResolution,
        observed: HyMT2ObservedPronounClass
    ) -> String {
        "pronoun marker \(identifier) expected \(expected.rawValue), observed \(observed.rawValue)"
    }
}

struct OutputValidationFailure: Error, Equatable, Sendable {
    let issues: [OutputValidationIssue]
    let pronounRealizations: [HyMT2PronounRealization]

    init(
        issues: [OutputValidationIssue],
        pronounRealizations: [HyMT2PronounRealization] = []
    ) {
        self.issues = issues
        self.pronounRealizations = pronounRealizations
    }

    var safeDescriptions: [String] {
        issues.map(\.safeDescription)
    }
}

extension OutputValidationIssue {
    var safeDescription: String {
        switch self {
        case .negativePronounSourceRange, .emptyPronounSourceRange,
            .pronounSourceRangeOutOfBounds, .pronounSourceRangeNotOnCharacterBoundary,
            .duplicatePronounSourceRange, .overlappingPronounSourceRanges,
            .pronounSourceRangeWrongGlyph, .tooManyPronounOccurrences,
            .reservedPronounMarkerCollision, .missingPronounMarker,
            .duplicatePronounMarker, .unknownPronounMarker, .malformedPronounMarker,
            .pronounMarkerOrderMismatch, .pronounMarkerResolutionMismatch,
            .pronounAlternativeList:
            "pronoun protocol validation failed"
        case .reusedPronounRealization, .wrongPronounRealization:
            "pronoun alignment validation failed"
        case .missingTerm:
            "missing required term"
        case .missingNumber:
            "missing source number"
        case .empty, .implausibleLength, .contextReplay, .metaText, .promptControlDelimiter,
            .unexpectedSourceScript, .missingNegation, .malformedScriptureReference:
            description
        }
    }

    var isPronounValidationIssue: Bool {
        switch self {
        case .negativePronounSourceRange, .emptyPronounSourceRange,
            .pronounSourceRangeOutOfBounds, .pronounSourceRangeNotOnCharacterBoundary,
            .duplicatePronounSourceRange, .overlappingPronounSourceRanges,
            .pronounSourceRangeWrongGlyph, .tooManyPronounOccurrences,
            .reservedPronounMarkerCollision, .missingPronounMarker,
            .duplicatePronounMarker, .unknownPronounMarker, .malformedPronounMarker,
            .pronounMarkerOrderMismatch, .pronounMarkerResolutionMismatch,
            .reusedPronounRealization,
            .pronounAlternativeList, .wrongPronounRealization:
            true
        case .empty, .implausibleLength, .contextReplay, .metaText, .promptControlDelimiter,
            .unexpectedSourceScript, .missingTerm, .missingNumber,
            .missingNegation, .malformedScriptureReference:
            false
        }
    }
}
