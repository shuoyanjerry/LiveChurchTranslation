import ASRAPI
import ASRNormalizationAPI
import DiscourseResolutionAPI
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
    private var discourseContext = DiscourseContextWindow()

    init(dependencies: LiveSessionDependencies) {
        self.dependencies = dependencies
    }

    func resetContext() {
        translationContext.removeAll()
        discourseContext.removeAll()
    }

    func recognize(_ segment: SpeechSegment) async throws -> RecognizedInput {
        try await recognize(segment, discourseContext: discourseContext.entries)
    }

    func recognize(
        _ segment: SpeechSegment,
        discourseContext: [VerifiedDiscourseTurn]
    ) async throws -> RecognizedInput {
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
            let resolved = resolveDiscourse(
                normalized,
                sequence: Int(clamping: segment.sequenceNumber),
                context: discourseContext
            )
            await recordRecognition(resolved.utterance, original: recognition, segment: segment)
            return RecognizedInput(
                utterance: resolved.utterance,
                glossary: enabled,
                sourceAudit: resolved.audit
            )
        } catch let failure as UtteranceProcessingFailure {
            throw failure
        } catch ASRError.filteredNonspeech {
            throw IgnoredUtterance(message: ASRError.filteredNonspeech.localizedDescription)
        } catch ASRError.promptOnlyHallucination {
            throw IgnoredUtterance(message: ASRError.promptOnlyHallucination.localizedDescription)
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
        discourseContext.append(
            VerifiedDiscourseTurn(sequence: entry.sequence, text: entry.sourceText)
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
