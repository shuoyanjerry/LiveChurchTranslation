import ASRAPI
import ASRNormalizationAPI
import Foundation
import GlossaryAPI
import SettingsAPI
import TranscriptAPI
import TranslationAPI

extension UtteranceProcessor {
    func asrPrompt(from entries: [GlossaryEntry], mode: TranslationMode) -> String {
        ASRContextTermSelector.prompt(from: entries, mode: mode)
    }

    func normalizedRecognition(
        _ utterance: RecognizedUtterance,
        entries: [GlossaryEntry],
        mode: TranslationMode
    ) -> (utterance: RecognizedUtterance, audit: TranscriptSourceAudit) {
        guard mode == .mandarinToEnglish else {
            return (
                utterance,
                TranscriptSourceAudit(rawText: utterance.rawText, corrections: [])
            )
        }
        let result = dependencies.asrNormalizer.normalizeWithAudit(
            utterance.text,
            using: normalizationRules(from: entries)
        )
        let normalized = RecognizedUtterance(
            id: utterance.id,
            sourceSegmentID: utterance.sourceSegmentID,
            rawText: utterance.rawText,
            text: result.normalizedText,
            confidence: utterance.confidence,
            startedAt: utterance.startedAt,
            endedAt: utterance.endedAt
        )
        let corrections = result.changes.map {
            TranscriptSourceCorrection(
                observedText: $0.recognitionAlias,
                replacementText: $0.canonicalText,
                kind: .recognitionNormalization
            )
        }
        return (
            normalized,
            TranscriptSourceAudit(rawText: utterance.rawText, corrections: corrections)
        )
    }

    func matchedTerms(
        in source: String,
        entries: [GlossaryEntry],
        mode: TranslationMode
    ) -> [TranslationTerm] {
        let glossaryTerms = translatedTerms(entries, mode: mode)
            .filter { entry in
                ([entry.source] + entry.sourceAliases).contains {
                    source.localizedStandardContains($0)
                }
            }
        let scriptureTerms = ScriptureBookTermCatalog.matchedTerms(in: source, mode: mode)
        return (glossaryTerms + scriptureTerms)
            .sorted { $0.source.count > $1.source.count }
    }

    private func translatedTerms(
        _ entries: [GlossaryEntry],
        mode: TranslationMode
    ) -> [TranslationTerm] {
        entries.map { entry in
            switch mode {
            case .mandarinToEnglish:
                TranslationTerm(
                    source: entry.source,
                    target: entry.target,
                    sourceAliases: entry.sourceAliases,
                    acceptedTargets: entry.targetVariants,
                    requirement: requirement(entry)
                )
            case .englishToSimplifiedChinese:
                TranslationTerm(
                    source: entry.target,
                    target: entry.source,
                    sourceAliases: entry.targetVariants,
                    acceptedTargets: entry.sourceAliases,
                    requirement: requirement(entry)
                )
            }
        }
    }

    private func requirement(_ entry: GlossaryEntry) -> TranslationTermRequirement {
        entry.enforcement == .required ? .required : .preferred
    }

    private func normalizationRules(
        from entries: [GlossaryEntry]
    ) -> [ASRNormalizationRule] {
        entries.flatMap { entry in
            entry.recognitionAliases.map {
                ASRNormalizationRule(
                    recognitionAlias: $0,
                    canonicalText: entry.source
                )
            }
        }
    }
}
