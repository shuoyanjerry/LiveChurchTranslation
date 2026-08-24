import Foundation

enum HyMT2PronounProtocolResidualValidator {
    static func validate(
        _ output: String,
        excluding ranges: [Range<String.Index>],
        plan: HyMT2PronounPlan
    ) throws {
        let remainder = outputRemoving(ranges, from: output)
        guard !containsProtocolFragment(in: remainder, plan: plan) else {
            throw OutputValidationFailure(issues: [.malformedPronounMarker])
        }
    }

    static func containsProtocolFragment(
        in value: String,
        plan: HyMT2PronounPlan?
    ) -> Bool {
        let normalized = HyMT2ReservedProtocolText.inspectionForm(value).uppercased()
        let inspection =
            normalized
            .filter { !$0.isWhitespace }
        return containsProtocolFragment(inspection, normalized: normalized, plan: plan)
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

    private static func containsProtocolFragment(
        _ value: String,
        normalized: String,
        plan: HyMT2PronounPlan?
    ) -> Bool {
        let containsReservedTag =
            HyMT2ReservedProtocolText.containsPrefix(in: value)
            || ["<QLR", "</QLR", "&LT;QLR", "&LT;/QLR"].contains(where: value.contains)
        if containsReservedTag {
            return true
        }
        guard let plan else { return false }
        if value.contains("QLR") { return true }
        if containsReservedOrdinal(in: normalized) { return true }
        if identifiers(in: plan).contains(where: { containsToken($0, in: normalized) }) {
            return true
        }
        return namespaces(in: plan).contains(where: value.contains)
    }

    static func containsReservedOrdinal(in value: String) -> Bool {
        let inspected = HyMT2ReservedProtocolText.inspectionForm(value)
        guard
            let expression = try? NSRegularExpression(
                pattern: #"(?<![A-Z0-9])P\s*[0-9]\s*[0-9]\s*[0-9]\s*[0-9](?![A-Z0-9])"#,
                options: .caseInsensitive
            )
        else { return true }
        return expression.firstMatch(
            in: inspected,
            range: NSRange(inspected.startIndex..., in: inspected)
        ) != nil
    }

    private static func containsToken(_ token: String, in value: String) -> Bool {
        let escaped = token.uppercased().map {
            NSRegularExpression.escapedPattern(for: String($0))
        }.joined(separator: #"\s*"#)
        guard
            let expression = try? NSRegularExpression(
                pattern: "(?<![A-Z0-9])\(escaped)(?![A-Z0-9])"
            )
        else { return true }
        return expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ) != nil
    }

    private static func identifiers(in plan: HyMT2PronounPlan) -> Set<String> {
        Set(plan.occurrences.map(\.identifier))
    }

    private static func namespaces(in plan: HyMT2PronounPlan) -> Set<String> {
        Set(
            plan.occurrences.compactMap { occurrence in
                occurrence.markerName.split(separator: "_").first.map(String.init)
            }
        )
    }
}
