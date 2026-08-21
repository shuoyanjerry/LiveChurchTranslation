import ASRNormalizationAPI

enum BuiltInASRNormalizationRules {
    static let rules = [
        ASRNormalizationRule(
            recognitionAlias: "在圣灵里承受",
            canonicalText: "在圣灵里成圣"
        ),
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
