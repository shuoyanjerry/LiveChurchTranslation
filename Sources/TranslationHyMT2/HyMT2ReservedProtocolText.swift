import Foundation

enum HyMT2ReservedProtocolText {
    static func containsPrefix(in value: String) -> Bool {
        inspectionForm(value).range(of: "QLR_", options: .caseInsensitive) != nil
    }

    static func inspectionForm(_ value: String) -> String {
        value.replacingOccurrences(
            of: #"\p{Cf}"#,
            with: "",
            options: .regularExpression
        ).precomposedStringWithCompatibilityMapping
    }
}
