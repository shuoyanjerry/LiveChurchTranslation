import Foundation

enum HyMT2ReservedProtocolText {
    static func containsPrefix(in value: String) -> Bool {
        let inspected = inspectionForm(value)
            .filter { !$0.isWhitespace }
            .uppercased()
        if inspected.contains("QLR_") { return true }
        guard
            let expression = try? NSRegularExpression(
                pattern: #"(?:<|&LT;)Q[A-F0-9]{12}P[0-9]{0,4}[NFMD]?"#
            )
        else { return true }
        return expression.firstMatch(
            in: inspected,
            range: NSRange(inspected.startIndex..., in: inspected)
        ) != nil
    }

    static func inspectionForm(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"\p{Cf}"#,
            with: "",
            options: .regularExpression
        ).precomposedStringWithCompatibilityMapping
    }
}
