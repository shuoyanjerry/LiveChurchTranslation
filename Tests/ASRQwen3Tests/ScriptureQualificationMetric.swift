import ASRQualificationSupport
import ScriptureQualificationSupport

struct ScriptureQualificationMetric: Sendable {
    let editCount: Int
    let referenceUnitCount: Int
    let referencePunctuationCount: Int
    let hypothesisPunctuationCount: Int
    let punctuationEditCount: Int

    static func measure(
        reference: String,
        hypothesis: String,
        lane: ScriptureQualificationLane
    ) throws -> Self {
        let text: (edits: Int, referenceUnits: Int)
        switch lane.metricUnit {
        case .word:
            let measurement = ASRQualificationTextMetrics.normalizedEnglishWER(
                reference: reference,
                hypothesis: hypothesis
            )
            text = (measurement.editCount, measurement.referenceWordCount)
        case .character:
            let measurement = ASRQualificationTextMetrics.normalizedStrictCER(
                reference: reference,
                hypothesis: hypothesis
            )
            text = (measurement.editCount, measurement.referenceCharacterCount)
        }
        let punctuation = try ScripturePunctuationFidelityMetric.measure(
            reference: reference,
            hypothesis: hypothesis
        )
        return Self(
            editCount: text.edits,
            referenceUnitCount: text.referenceUnits,
            referencePunctuationCount: punctuation.referencePunctuationCount,
            hypothesisPunctuationCount: punctuation.hypothesisPunctuationCount,
            punctuationEditCount: punctuation.anchoredEditDistance
        )
    }
}
