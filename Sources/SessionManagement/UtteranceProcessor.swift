import ASRAPI
import ASRNormalizationAPI
import DiagnosticsAPI
import Foundation
import GlossaryAPI
import PersistenceAPI
import SessionManagementAPI
import TranscriptAPI
import TranslationAPI
import VADAPI

struct UtteranceProcessingFailure: LocalizedError, Sendable {
    let stage: LiveSessionIssueStage
    let message: String
    let pendingEntry: TranscriptEntry?

    var errorDescription: String? { message }
}

actor UtteranceProcessor {
    struct RecognizedInput: Sendable {
        let utterance: RecognizedUtterance
        let glossary: [GlossaryEntry]
        let sourceAudit: TranscriptSourceAudit
    }

    let dependencies: LiveSessionDependencies
    private var translationContext = TranslationContextWindow()

    init(dependencies: LiveSessionDependencies) {
        self.dependencies = dependencies
    }

    func resetContext() {
        translationContext.removeAll()
    }

    func recognize(_ segment: SpeechSegment) async throws -> RecognizedInput {
        do {
            let glossary = try await dependencies.glossary.snapshot()
            let enabled = glossary.entries.filter(\.isEnabled)
            let recognition = try await dependencies.asr.transcribe(
                ASRRequest(
                    segment: segment,
                    contextPrompt: asrPrompt(from: enabled)
                )
            )
            let normalized = normalizedRecognition(recognition, entries: enabled)
            await recordRecognition(normalized.utterance, original: recognition, segment: segment)
            return RecognizedInput(
                utterance: normalized.utterance,
                glossary: enabled,
                sourceAudit: normalized.audit
            )
        } catch let failure as UtteranceProcessingFailure {
            throw failure
        } catch {
            throw failure(stage: .recognition, error: error)
        }
    }

    func translate(_ input: RecognizedInput, sessionID: UUID) async throws -> TranscriptEntry {
        let translation = try await translate(input)
        let entry = try await makeEntry(
            recognition: input.utterance,
            translation: translation,
            sourceAudit: input.sourceAudit
        )
        try await persist(entry, sessionID: sessionID)
        translationContext.append(
            TranslationContextEntry(
                sourceText: entry.sourceText,
                targetText: entry.targetText
            )
        )
        await dependencies.transcript.append(entry)
        await recordTranslation(duration: translation.duration)
        return entry
    }

    private func translate(_ input: RecognizedInput) async throws -> TranslationResult {
        do {
            let request = TranslationRequest(
                sourceText: input.utterance.text,
                glossary: matchedTerms(in: input.utterance.text, entries: input.glossary),
                context: translationContext.entries
            )
            return try await dependencies.translator.translate(request)
        } catch {
            throw failure(stage: .translation, error: error)
        }
    }

    private func persist(_ entry: TranscriptEntry, sessionID: UUID) async throws {
        do {
            try await dependencies.transcriptStore.append(entry, to: sessionID)
        } catch {
            throw failure(stage: .persistence, error: error, pendingEntry: entry)
        }
    }
}

extension UtteranceProcessor {
    private func recordTranslation(duration: Duration) async {
        await dependencies.diagnostics.record(
            DiagnosticEvent(
                severity: .info,
                component: "Translation",
                message: "Translated utterance",
                measurements: ["latency_ms": duration.milliseconds]
            )
        )
    }

    private func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit
    ) async throws -> TranscriptEntry {
        do {
            return try await dependencies.transcript.makeEntry(
                recognition: recognition,
                translation: translation,
                sourceAudit: sourceAudit
            )
        } catch {
            throw failure(stage: .persistence, error: error)
        }
    }

    private func recordRecognition(
        _ normalized: RecognizedUtterance,
        original: RecognizedUtterance,
        segment: SpeechSegment
    ) async {
        await dependencies.diagnostics.record(
            DiagnosticEvent(
                severity: .info,
                component: "ASR",
                message: "Recognized utterance",
                measurements: [
                    "audio_seconds": segment.duration.seconds,
                    "normalization_applied": normalized.text == original.text ? 0.0 : 1.0,
                ]
            )
        )
    }

    private func failure(
        stage: LiveSessionIssueStage,
        error: any Error,
        pendingEntry: TranscriptEntry? = nil
    ) -> UtteranceProcessingFailure {
        UtteranceProcessingFailure(
            stage: stage,
            message: error.localizedDescription,
            pendingEntry: pendingEntry
        )
    }
}

extension Duration {
    fileprivate var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    fileprivate var milliseconds: Double { seconds * 1_000 }
}
