import Foundation

enum HyMT2PronounProtocolResidualValidator {
    static func validate(
        _ output: String,
        excluding ranges: [Range<String.Index>],
        plan: HyMT2PronounPlan
    ) throws {
        let remainder = outputRemoving(ranges, from: output)
        let inspection = HyMT2ReservedProtocolText.inspectionForm(remainder).uppercased()
        guard !containsProtocolFragment(inspection, plan: plan) else {
            throw OutputValidationFailure(issues: [.malformedPronounMarker])
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

    private static func containsProtocolFragment(
        _ value: String,
        plan: HyMT2PronounPlan
    ) -> Bool {
        let containsIdentifier =
            value.contains("QLR")
            || containsOrdinalFragment(value)
            || containsNonceFragment(value)
        if containsIdentifier {
            return true
        }
        if ["<Q", "</Q", "&LT;Q", "&LT;/Q"].contains(where: value.contains) {
            return true
        }
        return namespaces(in: plan).contains(where: value.contains)
    }

    private static func containsOrdinalFragment(_ value: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: #"P[0-9]{1,4}"#) else {
            return true
        }
        return expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ) != nil
    }

    private static func containsNonceFragment(_ value: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: #"[A-F0-9]{12}"#) else {
            return true
        }
        return expression.firstMatch(
            in: value,
            range: NSRange(value.startIndex..., in: value)
        ) != nil
    }

    private static func namespaces(in plan: HyMT2PronounPlan) -> Set<String> {
        Set(
            plan.occurrences.compactMap { occurrence in
                occurrence.markerName.split(separator: "_").first.map(String.init)
            }
        )
    }
}
