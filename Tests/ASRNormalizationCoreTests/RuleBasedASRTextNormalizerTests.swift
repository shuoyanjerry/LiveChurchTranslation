import ASRNormalizationAPI
import ASRNormalizationCore
import Testing

@Suite struct RuleBasedASRTextNormalizerTests {
    private let normalizer = RuleBasedASRTextNormalizer()

    @Test func repairsObservedQwenTheologicalMisrecognitions() {
        let raw = "休恩出于恩典，我们因信生义。"

        let result = normalizer.normalize(raw, using: [])

        #expect(result == "救恩出于恩典，我们因信称义。")
    }

    @Test func appliesUserEditableRecognitionAlias() {
        let rule = ASRNormalizationRule(
            recognitionAlias: "喜礼",
            canonicalText: "洗礼"
        )

        #expect(normalizer.normalize("领受喜礼", using: [rule]) == "领受洗礼")
    }

    @Test func longestMatchWinsRegardlessOfRuleOrder() {
        let rules = [
            ASRNormalizationRule(recognitionAlias: "因信", canonicalText: "藉着信心"),
            ASRNormalizationRule(recognitionAlias: "因信生义", canonicalText: "因信称义"),
        ]

        #expect(normalizer.normalize("因信生义", using: rules) == "因信称义")
    }

    @Test func replacementDoesNotCascade() {
        let rules = [
            ASRNormalizationRule(recognitionAlias: "甲", canonicalText: "乙"),
            ASRNormalizationRule(recognitionAlias: "乙", canonicalText: "丙"),
        ]

        #expect(normalizer.normalize("甲", using: rules) == "乙")
    }

    @Test func userRuleOverridesBuiltInRuleWithSameAlias() {
        let rule = ASRNormalizationRule(
            recognitionAlias: "休恩",
            canonicalText: "用户指定词"
        )

        #expect(normalizer.normalize("休恩", using: [rule]) == "用户指定词")
    }

    @Test func invalidRulesLeaveInputUntouched() {
        let rules = [
            ASRNormalizationRule(recognitionAlias: " ", canonicalText: "救恩"),
            ASRNormalizationRule(recognitionAlias: "误听", canonicalText: " "),
            ASRNormalizationRule(recognitionAlias: "原文", canonicalText: "原文"),
        ]

        #expect(normalizer.normalize("原文 误听", using: rules) == "原文 误听")
    }

    @Test func reportsOriginalTextAndEveryAppliedCorrection() {
        let result = normalizer.normalizeWithAudit("休恩和因信生义", using: [])

        #expect(result.originalText == "休恩和因信生义")
        #expect(result.normalizedText == "救恩和因信称义")
        #expect(
            result.changes == [
                ASRNormalizationChange(recognitionAlias: "休恩", canonicalText: "救恩"),
                ASRNormalizationChange(recognitionAlias: "因信生义", canonicalText: "因信称义"),
            ]
        )
    }

    @Test func doesNotRewriteAmbiguousHolySpiritPhraseGlobally() {
        #expect(normalizer.normalize("在圣灵里承受产业", using: []) == "在圣灵里承受产业")
    }
}
