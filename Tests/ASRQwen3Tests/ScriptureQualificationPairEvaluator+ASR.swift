import ASRAPI
import ScriptureQualificationSupport
import VADAPI

extension ScriptureQualificationPairEvaluator {
    func transcribe(
        item: ScriptureQualificationVerifiedItem,
        reference: String,
        lane: ScriptureQualificationLane
    ) async -> ScriptureQualificationASRStage {
        let segment: SpeechSegment
        do {
            segment = try await ScriptureQualificationContentLoader.speechSegment(
                at: item.audioURL
            )
        } catch {
            return failedASR(item, lane: lane, code: .audioDecodeFailed)
        }
        let started = ContinuousClock.now
        do {
            let output = try await recognizedText(segment: segment, item: item)
            return measuredASR(
                output: output,
                input: ScriptureQualificationMeasurementInput(
                    reference: reference,
                    lane: lane,
                    partition: item.metadata.partition,
                    audioSeconds: segment.duration.qwenQualificationSeconds,
                    runtimeSeconds: started.duration(to: .now).qwenQualificationSeconds
                )
            )
        } catch {
            return failedASR(
                item,
                lane: lane,
                code: .asrFailed,
                audioSeconds: segment.duration.qwenQualificationSeconds,
                runtimeSeconds: started.duration(to: .now).qwenQualificationSeconds
            )
        }
    }

    private func recognizedText(
        segment: SpeechSegment,
        item: ScriptureQualificationVerifiedItem
    ) async throws -> String {
        let result = try await asr.transcribe(
            request(segment: segment, language: item.metadata.languageTag)
        )
        return ScriptureProductionLanguagePolicy.normalizedASROutput(
            result.text,
            sourceLanguage: item.metadata.languageTag
        )
    }

    private func request(segment: SpeechSegment, language: String) -> ASRRequest {
        ASRRequest(
            segment: segment,
            languageCode: recognitionCode(language),
            contextPrompt: ScriptureProductionLanguagePolicy.asrPrompt(
                sourceLanguage: language
            )
        )
    }

    private func measuredASR(
        output: String,
        input: ScriptureQualificationMeasurementInput
    ) -> ScriptureQualificationASRStage {
        do {
            let metric = try ScriptureQualificationMetric.measure(
                reference: input.reference,
                hypothesis: output,
                lane: input.lane
            )
            return ScriptureQualificationASRStage(
                observation: .success(
                    partition: input.partition,
                    lane: input.lane,
                    metric: metric,
                    audioSeconds: input.audioSeconds,
                    runtimeSeconds: input.runtimeSeconds
                ),
                text: output
            )
        } catch {
            return ScriptureQualificationASRStage(
                observation: .failure(
                    partition: input.partition,
                    lane: input.lane,
                    code: .metricFailed,
                    audioSeconds: input.audioSeconds,
                    runtimeSeconds: input.runtimeSeconds
                ),
                text: output
            )
        }
    }

    private func failedASR(
        _ item: ScriptureQualificationVerifiedItem,
        lane: ScriptureQualificationLane,
        code: ScriptureQualificationFailureCode,
        audioSeconds: Double = 0,
        runtimeSeconds: Double = 0
    ) -> ScriptureQualificationASRStage {
        ScriptureQualificationASRStage(
            observation: .failure(
                partition: item.metadata.partition,
                lane: lane,
                code: code,
                audioSeconds: audioSeconds,
                runtimeSeconds: runtimeSeconds
            ),
            text: nil
        )
    }

    private func recognitionCode(_ language: String) -> String {
        language.lowercased().hasPrefix("zh") ? "zh" : "en"
    }
}
