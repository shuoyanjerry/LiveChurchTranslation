import Foundation

enum HyMT2NegationShadowEncoding: String, CaseIterable, Sendable {
    case englishNot
    case originalCue
}

enum HyMT2NegationShadowFailureCategory: String, CaseIterable, Error, Sendable {
    case duplicateBlock = "block.duplicate"
    case invalidSourceRange = "source.range"
    case missingBlock = "block.missing"
    case overlappingSourceRange = "source.overlap"
    case reservedProtocolInput = "source.reserved"
    case residualProtocol = "protocol.residual"
    case tooManyOccurrences = "occurrence.limit"
    case unboundNegator = "negator.unbound"
    case unexpectedBlock = "block.unexpected"
    case unexpectedError = "error.unexpected"
    case wrongSourceCue = "source.cue"
}

struct HyMT2NegationShadowFailure: Error, Equatable, Sendable {
    let category: HyMT2NegationShadowFailureCategory
    let identifier: String?
}

struct HyMT2NegationShadowSourceCue: Equatable, Sendable {
    let range: NSRange
    let text: String
}

struct HyMT2NegationShadowOccurrence: Equatable, Sendable {
    let identifier: String
    let nonce: String
    let sourceCue: HyMT2NegationShadowSourceCue

    var markerName: String {
        "QLR_NEG_\(nonce)_\(identifier)"
    }

    var protectedBlock: String {
        "<\(markerName)>QLR_NEG_LOCK</\(markerName)>"
    }
}

struct HyMT2NegationShadowPlan: Equatable, Sendable {
    let source: String
    let protectedSource: String
    let encoding: HyMT2NegationShadowEncoding
    let occurrences: [HyMT2NegationShadowOccurrence]

    static func make(
        source: String,
        functionalCues: [HyMT2NegationShadowSourceCue],
        requestID: UUID,
        encoding: HyMT2NegationShadowEncoding
    ) throws -> HyMT2NegationShadowPlan {
        guard !source.uppercased().contains("QLR_NEG") else {
            throw failure(.reservedProtocolInput)
        }
        guard functionalCues.count <= maximumOccurrenceCount else {
            throw failure(.tooManyOccurrences)
        }
        let cues = try validate(functionalCues, in: source)
        let nonce = markerNonce(requestID)
        let occurrences = cues.enumerated().map { index, cue in
            HyMT2NegationShadowOccurrence(
                identifier: String(format: "N%04d", index + 1),
                nonce: nonce,
                sourceCue: cue
            )
        }
        return HyMT2NegationShadowPlan(
            source: source,
            protectedSource: insertMarkers(in: source, occurrences: occurrences, encoding: encoding),
            encoding: encoding,
            occurrences: occurrences
        )
    }

    private static let maximumOccurrenceCount = 9_999

    private static func validate(
        _ cues: [HyMT2NegationShadowSourceCue],
        in source: String
    ) throws -> [HyMT2NegationShadowSourceCue] {
        let ordered = cues.sorted {
            ($0.range.location, $0.range.length) < ($1.range.location, $1.range.length)
        }
        var previousEnd = 0
        for (index, cue) in ordered.enumerated() {
            guard let range = stringRange(cue.range, in: source) else {
                throw failure(.invalidSourceRange)
            }
            if index > 0, cue.range.location < previousEnd {
                throw failure(.overlappingSourceRange)
            }
            guard source[range] == cue.text else { throw failure(.wrongSourceCue) }
            previousEnd = cue.range.location + cue.range.length
        }
        return ordered
    }

    private static func stringRange(_ range: NSRange, in source: String) -> Range<String.Index>? {
        guard range.location >= 0, range.length > 0 else { return nil }
        let count = source.utf16.count
        guard range.location <= count, range.length <= count - range.location else { return nil }
        return Range(range, in: source)
    }

    private static func markerNonce(_ requestID: UUID) -> String {
        String(requestID.uuidString.replacingOccurrences(of: "-", with: "").prefix(12))
    }

    private static func insertMarkers(
        in source: String,
        occurrences: [HyMT2NegationShadowOccurrence],
        encoding: HyMT2NegationShadowEncoding
    ) -> String {
        var result = ""
        var cursor = source.startIndex
        for occurrence in occurrences {
            guard let range = Range(occurrence.sourceCue.range, in: source) else { continue }
            result += source[cursor..<range.lowerBound]
            if encoding == .englishNot {
                result += " not" + occurrence.protectedBlock + " "
            } else {
                result += occurrence.sourceCue.text + occurrence.protectedBlock
            }
            cursor = range.upperBound
        }
        result += source[cursor...]
        return result
    }

    private static func failure(
        _ category: HyMT2NegationShadowFailureCategory
    ) -> HyMT2NegationShadowFailure {
        HyMT2NegationShadowFailure(category: category, identifier: nil)
    }
}
