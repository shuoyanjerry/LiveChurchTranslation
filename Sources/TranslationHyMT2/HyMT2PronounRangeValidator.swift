import Foundation
import TranslationAPI

struct ValidatedPronounGuidance {
    let guidance: TranslationPronounGuidance
    let glyph: String
}

enum HyMT2PronounRangeValidator {
    static func validate(
        source: String,
        guidance: [TranslationPronounGuidance]
    ) throws -> [ValidatedPronounGuidance] {
        let ordered = guidance.sorted {
            ($0.sourceRange.location, $0.sourceRange.length)
                < ($1.sourceRange.location, $1.sourceRange.length)
        }
        let ranged = try ordered.map { item in
            ValidatedPronounGuidance(
                guidance: item,
                glyph: try glyphForRange(item.sourceRange, in: source)
            )
        }
        for pair in zip(ranged, ranged.dropFirst()) {
            try validateSeparation(pair.0.guidance.sourceRange, pair.1.guidance.sourceRange)
        }
        for item in ranged where !["他", "她", "祂"].contains(item.glyph) {
            throw failure(.pronounSourceRangeWrongGlyph(item.guidance.sourceRange.location))
        }
        return ranged
    }

    private static func glyphForRange(
        _ range: TranslationSourceRange,
        in source: String
    ) throws -> String {
        guard range.location >= 0, range.length >= 0 else {
            throw failure(.negativePronounSourceRange(range.location, range.length))
        }
        guard range.length > 0 else {
            throw failure(.emptyPronounSourceRange(range.location))
        }
        let count = source.utf16.count
        guard range.location <= count, range.length <= count - range.location else {
            throw failure(.pronounSourceRangeOutOfBounds(range.location, range.length))
        }
        let end = range.location + range.length
        guard isCharacterBoundary(range.location, in: source),
            isCharacterBoundary(end, in: source)
        else {
            throw failure(.pronounSourceRangeNotOnCharacterBoundary(range.location, range.length))
        }
        let nsRange = NSRange(location: range.location, length: range.length)
        guard let stringRange = Range(nsRange, in: source) else {
            throw failure(.pronounSourceRangeNotOnCharacterBoundary(range.location, range.length))
        }
        return String(source[stringRange])
    }

    private static func isCharacterBoundary(_ offset: Int, in source: String) -> Bool {
        if offset == source.utf16.count { return true }
        let index = String.Index(utf16Offset: offset, in: source)
        return source.indices.contains(index)
    }

    private static func validateSeparation(
        _ previous: TranslationSourceRange,
        _ current: TranslationSourceRange
    ) throws {
        if previous == current {
            throw failure(.duplicatePronounSourceRange(current.location, current.length))
        }
        if current.location < previous.location + previous.length {
            throw failure(.overlappingPronounSourceRanges(previous.location, current.location))
        }
    }

    private static func failure(_ issue: OutputValidationIssue) -> OutputValidationFailure {
        OutputValidationFailure(issues: [issue])
    }
}
