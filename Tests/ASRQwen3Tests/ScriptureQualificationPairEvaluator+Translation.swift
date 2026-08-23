import ScriptureQualificationSupport
import TranslationAPI
import TranslationHyMT2

extension ScriptureQualificationPairEvaluator {
    func translationObservations(
        _ content: ScriptureQualificationPairContent,
        englishASR: ScriptureQualificationASRStage,
        chineseASR: ScriptureQualificationASRStage
    ) async -> [ScriptureQualificationObservation] {
        let englishClean = await translate(
            source: content.englishReference,
            reference: content.simplifiedChineseReference,
            sourceLanguage: "en",
            lane: .englishToSimplifiedChineseCleanText,
            partition: content.partition
        )
        let chineseClean = await translate(
            source: content.simplifiedChineseReference,
            reference: content.englishReference,
            sourceLanguage: "zh-Hans",
            lane: .simplifiedChineseToEnglishCleanText,
            partition: content.partition
        )
        let englishEndToEnd = await endToEnd(
            stage: englishASR,
            reference: content.simplifiedChineseReference,
            sourceLanguage: "en",
            lane: .englishASRToSimplifiedChinese,
            partition: content.partition
        )
        let chineseEndToEnd = await endToEnd(
            stage: chineseASR,
            reference: content.englishReference,
            sourceLanguage: "zh-Hans",
            lane: .simplifiedChineseASRToEnglish,
            partition: content.partition
        )
        return [englishClean, chineseClean, englishEndToEnd, chineseEndToEnd]
    }

    private func endToEnd(
        stage: ScriptureQualificationASRStage,
        reference: String,
        sourceLanguage: String,
        lane: ScriptureQualificationLane,
        partition: ScriptureQualificationPartition
    ) async -> ScriptureQualificationObservation {
        guard let source = stage.text else {
            return .failure(partition: partition, lane: lane, code: .upstreamASRFailed)
        }
        return await translate(
            source: source,
            reference: reference,
            sourceLanguage: sourceLanguage,
            lane: lane,
            partition: partition,
            precedingRuntimeSeconds: stage.observation.runtimeSeconds,
            audioSeconds: stage.observation.audioSeconds
        )
    }

    private func translate(
        source: String,
        reference: String,
        sourceLanguage: String,
        lane: ScriptureQualificationLane,
        partition: ScriptureQualificationPartition,
        precedingRuntimeSeconds: Double = 0,
        audioSeconds: Double = 0
    ) async -> ScriptureQualificationObservation {
        let started = ContinuousClock.now
        let output: String
        do {
            output = try await translator.translate(
                translationRequest(source: source, sourceLanguage: sourceLanguage)
            ).targetText
        } catch {
            let runtime =
                precedingRuntimeSeconds
                + started.duration(to: .now).qwenQualificationSeconds
            return translationFailure(
                partition: partition,
                lane: lane,
                runtimeSeconds: runtime,
                audioSeconds: audioSeconds,
                error: error
            )
        }
        let runtime =
            precedingRuntimeSeconds
            + started.duration(to: .now).qwenQualificationSeconds
        return measuredTranslation(
            output: output,
            input: ScriptureQualificationMeasurementInput(
                reference: reference,
                lane: lane,
                partition: partition,
                audioSeconds: audioSeconds,
                runtimeSeconds: runtime
            )
        )
    }

    private func translationRequest(
        source: String,
        sourceLanguage: String
    ) -> TranslationRequest {
        TranslationRequest(
            sourceText: source,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage(sourceLanguage),
            glossary: ScriptureProductionLanguagePolicy.translationTerms(
                in: source,
                sourceLanguage: sourceLanguage
            )
        )
    }

    private func measuredTranslation(
        output: String,
        input: ScriptureQualificationMeasurementInput
    ) -> ScriptureQualificationObservation {
        do {
            return .success(
                partition: input.partition,
                lane: input.lane,
                metric: try ScriptureQualificationMetric.measure(
                    reference: input.reference,
                    hypothesis: output,
                    lane: input.lane
                ),
                audioSeconds: input.audioSeconds,
                runtimeSeconds: input.runtimeSeconds
            )
        } catch {
            return .failure(
                partition: input.partition,
                lane: input.lane,
                code: .metricFailed,
                audioSeconds: input.audioSeconds,
                runtimeSeconds: input.runtimeSeconds
            )
        }
    }

    private func translationFailure(
        partition: ScriptureQualificationPartition,
        lane: ScriptureQualificationLane,
        runtimeSeconds: Double,
        audioSeconds: Double,
        error: any Error
    ) -> ScriptureQualificationObservation {
        .failure(
            partition: partition,
            lane: lane,
            code: .translationFailed,
            diagnosticCode: HyMT2SafeFailureCode.make(error),
            audioSeconds: audioSeconds,
            runtimeSeconds: runtimeSeconds
        )
    }

    private func targetLanguage(_ sourceLanguage: String) -> String {
        sourceLanguage.lowercased().hasPrefix("zh") ? "en" : "zh-Hans"
    }
}
