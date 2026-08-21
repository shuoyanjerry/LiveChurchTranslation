import ASRAPI
import ASRNormalizationAPI
import DiagnosticsAPI
import Foundation
import GlossaryAPI
import PersistenceAPI
import TranscriptAPI
import TranslationAPI
import VADAPI

actor UtteranceProcessor {
    struct RecognizedInput: Sendable {
        let utterance: RecognizedUtterance
        let glossary: [GlossaryEntry]
    }

    private let dependencies: LiveSessionDependencies

    init(dependencies: LiveSessionDependencies) {
        self.dependencies = dependencies
    }

    func recognize(_ segment: SpeechSegment) async throws -> RecognizedInput {
        let glossary = try await dependencies.glossary.snapshot()
        let enabled = glossary.entries.filter(\.isEnabled)
        let recognition = try await dependencies.asr.transcribe(
            ASRRequest(
                segment: segment,
                contextPrompt: asrPrompt(from: enabled)
            )
        )
        let normalized = normalize(recognition, entries: enabled)
        await dependencies.diagnostics.record(
            DiagnosticEvent(
                severity: .info,
                component: "ASR",
                message: "Recognized utterance",
                measurements: [
                    "audio_seconds": segment.duration.seconds,
                    "normalization_applied": normalized.text == recognition.text ? 0.0 : 1.0,
                ]
            )
        )
        return RecognizedInput(utterance: normalized, glossary: enabled)
    }

    func translate(_ input: RecognizedInput, sessionID: UUID) async throws -> TranscriptEntry {
        let request = TranslationRequest(
            sourceText: input.utterance.text,
            glossary: matchedTerms(in: input.utterance.text, entries: input.glossary)
        )
        let translation = try await dependencies.translator.translate(request)
        let entry = try await dependencies.transcript.makeEntry(
            recognition: input.utterance,
            translation: translation
        )
        try await dependencies.transcriptStore.append(entry, to: sessionID)
        await dependencies.transcript.append(entry)
        await dependencies.diagnostics.record(
            DiagnosticEvent(
                severity: .info,
                component: "Translation",
                message: "Translated utterance",
                measurements: ["latency_ms": translation.duration.milliseconds]
            )
        )
        return entry
    }

    private func asrPrompt(from entries: [GlossaryEntry]) -> String {
        entries
            .sorted { $0.source.count > $1.source.count }
            .prefix(48)
            .map(\.source)
            .joined(separator: ",")
    }

    private func normalize(
        _ utterance: RecognizedUtterance,
        entries: [GlossaryEntry]
    ) -> RecognizedUtterance {
        let rules = entries.flatMap { entry in
            entry.recognitionAliases.map {
                ASRNormalizationRule(
                    recognitionAlias: $0,
                    canonicalText: entry.source
                )
            }
        }
        let text = dependencies.asrNormalizer.normalize(utterance.text, using: rules)
        return RecognizedUtterance(
            id: utterance.id,
            sourceSegmentID: utterance.sourceSegmentID,
            text: text,
            confidence: utterance.confidence,
            startedAt: utterance.startedAt,
            endedAt: utterance.endedAt
        )
    }

    private func matchedTerms(
        in source: String,
        entries: [GlossaryEntry]
    ) -> [TranslationTerm] {
        entries
            .filter { source.localizedStandardContains($0.source) }
            .sorted { $0.source.count > $1.source.count }
            .map { TranslationTerm(source: $0.source, target: $0.target) }
    }
}

extension Duration {
    fileprivate var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    fileprivate var milliseconds: Double { seconds * 1_000 }
}
