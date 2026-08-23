import Foundation

struct HyMT2NegationShadowBinding: Equatable, Sendable {
    let identifier: String
    let englishNegator: String
}

struct HyMT2ParsedNegationShadow: Equatable, Sendable {
    let cleanTarget: String
    let bindings: [HyMT2NegationShadowBinding]
}

enum HyMT2NegationMarkerShadowParser {
    static func parse(
        _ output: String,
        plan: HyMT2NegationShadowPlan
    ) throws -> HyMT2ParsedNegationShadow {
        let located = try locateExpectedBlocks(in: output, plan: plan)
        try rejectUnexpectedProtocol(in: output, excluding: located.map(\.range), plan: plan)
        let bindings = try plan.occurrences.map { occurrence in
            guard let item = located.first(where: { $0.identifier == occurrence.identifier }) else {
                throw failure(.missingBlock, occurrence.identifier)
            }
            guard
                let negator = HyMT2NegationShadowEnglishNegator.adjacent(
                    before: item.range.lowerBound,
                    after: item.range.upperBound,
                    in: output
                )
            else {
                throw failure(.unboundNegator, occurrence.identifier)
            }
            return HyMT2NegationShadowBinding(
                identifier: occurrence.identifier,
                englishNegator: negator
            )
        }
        let clean = outputRemoving(located.map(\.range), from: output)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try rejectResidualProtocol(in: clean, plan: plan)
        return HyMT2ParsedNegationShadow(cleanTarget: clean, bindings: bindings)
    }

    private struct LocatedBlock {
        let identifier: String
        let range: Range<String.Index>
    }

    private static func locateExpectedBlocks(
        in output: String,
        plan: HyMT2NegationShadowPlan
    ) throws -> [LocatedBlock] {
        var located: [LocatedBlock] = []
        for occurrence in plan.occurrences {
            let ranges = ranges(of: occurrence.protectedBlock, in: output)
            if ranges.count > 1 { throw failure(.duplicateBlock, occurrence.identifier) }
            if let range = ranges.first {
                located.append(LocatedBlock(identifier: occurrence.identifier, range: range))
            }
        }
        return located.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }

    private static func ranges(
        of needle: String,
        in value: String
    ) -> [Range<String.Index>] {
        var result: [Range<String.Index>] = []
        var cursor = value.startIndex
        while cursor < value.endIndex {
            guard let range = value.range(of: needle, range: cursor..<value.endIndex) else { break }
            result.append(range)
            cursor = range.upperBound
        }
        return result
    }

    private static func rejectUnexpectedProtocol(
        in output: String,
        excluding excludedRanges: [Range<String.Index>],
        plan: HyMT2NegationShadowPlan
    ) throws {
        let remainder = outputRemoving(excludedRanges, from: output)
        if protocolInspection(remainder).contains("QLR") {
            throw failure(.unexpectedBlock, nil)
        }
        let missing = plan.occurrences.first { occurrence in
            ranges(of: occurrence.protectedBlock, in: output).isEmpty
        }
        if let missing { throw failure(.missingBlock, missing.identifier) }
    }

    private static func outputRemoving(
        _ ranges: [Range<String.Index>],
        from output: String
    ) -> String {
        var result = ""
        var cursor = output.startIndex
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            result += output[cursor..<range.lowerBound]
            cursor = range.upperBound
        }
        result += output[cursor...]
        return result
    }

    private static func rejectResidualProtocol(
        in clean: String,
        plan: HyMT2NegationShadowPlan
    ) throws {
        guard !containsProtocolFragment(clean, plan: plan) else {
            throw failure(.residualProtocol, nil)
        }
    }

    private static func containsProtocolFragment(
        _ value: String,
        plan: HyMT2NegationShadowPlan
    ) -> Bool {
        let inspection = protocolInspection(value)
        if inspection.contains("QLR") { return true }
        return plan.occurrences.contains {
            inspection.contains($0.nonce) || inspection.contains($0.identifier)
        }
    }

    private static func protocolInspection(_ value: String) -> String {
        String(value.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func failure(
        _ category: HyMT2NegationShadowFailureCategory,
        _ identifier: String?
    ) -> HyMT2NegationShadowFailure {
        HyMT2NegationShadowFailure(category: category, identifier: identifier)
    }
}
