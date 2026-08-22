import ASRAPI
import ASRNormalizationAPI
import Foundation
import GlossaryAPI
import TranscriptAPI
import TranslationAPI

extension UtteranceProcessor {
    func asrPrompt(from entries: [GlossaryEntry]) -> String {
        entries
            .sorted { $0.source.count > $1.source.count }
            .prefix(48)
            .map(\.source)
            .joined(separator: ",")
    }

    func normalizedRecognition(
        _ utterance: RecognizedUtterance,
        entries: [GlossaryEntry]
    ) -> (utterance: RecognizedUtterance, audit: TranscriptSourceAudit) {
        let result = dependencies.asrNormalizer.normalizeWithAudit(
            utterance.text,
            using: normalizationRules(from: entries)
        )
        let normalized = RecognizedUtterance(
            id: utterance.id,
            sourceSegmentID: utterance.sourceSegmentID,
            text: result.normalizedText,
            confidence: utterance.confidence,
            startedAt: utterance.startedAt,
            endedAt: utterance.endedAt
        )
        let corrections = result.changes.map {
            TranscriptSourceCorrection(
                observedText: $0.recognitionAlias,
                replacementText: $0.canonicalText
            )
        }
        return (
            normalized,
            TranscriptSourceAudit(rawText: result.originalText, corrections: corrections)
        )
    }

    func matchedTerms(
        in source: String,
        entries: [GlossaryEntry]
    ) -> [TranslationTerm] {
        entries
            .filter { entry in
                ([entry.source] + entry.sourceAliases).contains {
                    source.localizedStandardContains($0)
                }
            }
            .sorted { $0.source.count > $1.source.count }
            .map { entry in
                TranslationTerm(
                    source: entry.source,
                    target: entry.target,
                    sourceAliases: entry.sourceAliases,
                    acceptedTargets: entry.targetVariants,
                    requirement: entry.enforcement == .required ? .required : .preferred
                )
            }
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
