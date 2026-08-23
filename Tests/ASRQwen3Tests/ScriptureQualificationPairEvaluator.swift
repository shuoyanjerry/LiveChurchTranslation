import ASRQwen3
import ScriptureQualificationSupport
import TranslationHyMT2

struct ScriptureQualificationPairContent: Sendable {
    let englishItem: ScriptureQualificationVerifiedItem
    let simplifiedChineseItem: ScriptureQualificationVerifiedItem
    let englishReference: String
    let simplifiedChineseReference: String

    var partition: ScriptureQualificationPartition {
        englishItem.metadata.partition
    }
}

struct ScriptureQualificationPairEvaluator {
    let asr: Qwen3ASRProvider
    let translator: HyMT2TranslationProvider

    func evaluate(
        _ content: ScriptureQualificationPairContent
    ) async -> [ScriptureQualificationObservation] {
        let englishASR = await transcribe(
            item: content.englishItem,
            reference: content.englishReference,
            lane: .englishASR
        )
        let chineseASR = await transcribe(
            item: content.simplifiedChineseItem,
            reference: content.simplifiedChineseReference,
            lane: .simplifiedChineseASR
        )
        let translations = await translationObservations(
            content,
            englishASR: englishASR,
            chineseASR: chineseASR
        )
        return [englishASR.observation, chineseASR.observation] + translations
    }
}

struct ScriptureQualificationASRStage {
    let observation: ScriptureQualificationObservation
    let text: String?
}

struct ScriptureQualificationMeasurementInput {
    let reference: String
    let lane: ScriptureQualificationLane
    let partition: ScriptureQualificationPartition
    let audioSeconds: Double
    let runtimeSeconds: Double
}
