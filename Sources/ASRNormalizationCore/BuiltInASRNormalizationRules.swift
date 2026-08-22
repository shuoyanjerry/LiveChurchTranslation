import ASRNormalizationAPI

enum BuiltInASRNormalizationRules {
    static let rules = [
        ASRNormalizationRule(
            recognitionAlias: "因信生义",
            canonicalText: "因信称义"
        ),
        ASRNormalizationRule(
            recognitionAlias: "休恩",
            canonicalText: "救恩"
        ),
    ]
}
