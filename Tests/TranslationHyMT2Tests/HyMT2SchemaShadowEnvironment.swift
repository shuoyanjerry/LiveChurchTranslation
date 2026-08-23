import Foundation

enum HyMT2SchemaShadowEnvironment {
    static func load(
        _ values: [String: String]
    ) throws -> HyMT2NegationShadowQ4Environment {
        guard let report = values["HYMT_SCHEMA_SHADOW_REPORT"], !report.isEmpty else {
            throw HyMT2NegationShadowQ4EnvironmentError.missingEnvironment(
                "HYMT_SCHEMA_SHADOW_REPORT"
            )
        }
        var mapped = values
        mapped["HYMT_NEGATION_SHADOW_REPORT"] = report
        return try HyMT2NegationShadowQ4Environment.load(mapped)
    }
}
