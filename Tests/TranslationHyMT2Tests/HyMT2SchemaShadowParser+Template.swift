import Foundation
@testable import TranslationHyMT2

extension HyMT2SchemaShadowParser {
    static func validatePlaceholders(
        _ template: String,
        occurrences: [HyMT2SchemaShadowOccurrence]
    ) throws {
        for occurrence in occurrences {
            let ranges = ranges(of: occurrence.placeholder, in: template)
            if ranges.isEmpty { throw HyMT2SchemaShadowFailureCode.placeholderMissing }
            if ranges.count > 1 { throw HyMT2SchemaShadowFailureCode.placeholderDuplicate }
            guard let range = ranges.first, hasTokenBoundaries(range, in: template) else {
                throw HyMT2SchemaShadowFailureCode.placeholderBoundary
            }
        }
        guard !template.contains("}}{{") else {
            throw HyMT2SchemaShadowFailureCode.placeholderBoundary
        }
        let expected = Set(occurrences.map(\.placeholder))
        let observed = Set(matches(of: #"\{\{[PN][0-9]{4}\}\}"#, in: template))
        guard observed.isSubset(of: expected) else {
            throw HyMT2SchemaShadowFailureCode.placeholderUnknown
        }
    }

    static func reconstruct(
        _ template: String,
        occurrences: [HyMT2SchemaShadowOccurrence],
        bindings: [String: HyMT2SchemaShadowBinding]
    ) -> String {
        occurrences.reduce(template) { value, occurrence in
            value.replacingOccurrences(
                of: occurrence.placeholder,
                with: bindings[occurrence.identifier]?.surface ?? ""
            )
        }
    }

    static func rejectResidualProtocol(_ target: String) throws {
        guard !HyMT2ReservedProtocolText.containsPrefix(in: target),
            !HyMT2PromptControlDelimiter.occurs(in: target),
            !target.contains("{{"), !target.contains("}}"),
            matches(of: #"\[[PN][0-9]{4}\]"#, in: target).isEmpty
        else {
            throw HyMT2SchemaShadowFailureCode.protocolResidual
        }
    }

    private static func hasTokenBoundaries(
        _ range: Range<String.Index>,
        in value: String
    ) -> Bool {
        let left =
            range.lowerBound > value.startIndex
            ? value[value.index(before: range.lowerBound)] : nil
        let right = range.upperBound < value.endIndex ? value[range.upperBound] : nil
        return (left.map { !isWordCharacter($0) } ?? true)
            && (right.map { !isWordCharacter($0) } ?? true)
    }

    private static func isWordCharacter(_ value: Character) -> Bool {
        value.isLetter || value.isNumber || value == "'" || value == "’" || value == "_"
    }

    private static func ranges(
        of needle: String,
        in value: String
    ) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var cursor = value.startIndex
        while cursor < value.endIndex {
            guard let range = value.range(of: needle, range: cursor..<value.endIndex) else {
                break
            }
            result.append(range)
            cursor = range.upperBound
        }
        return result
    }

    private static func matches(of pattern: String, in value: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap {
            Range($0.range, in: value).map { String(value[$0]) }
        }
    }
}
