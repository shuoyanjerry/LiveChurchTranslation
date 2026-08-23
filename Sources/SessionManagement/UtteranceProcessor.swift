import ASRAPI
import ASRNormalizationAPI
import DiscourseResolutionAPI
import Foundation
import GlossaryAPI
import PersistenceAPI
import SessionManagementAPI
import SettingsAPI
import TranscriptAPI
import TranslationAPI
import VADAPI

struct UtteranceProcessingFailure: LocalizedError, Sendable {
    enum Impact: Equatable, Sendable {
        case terminalUtterance
        case retryableUtterance
        case pipeline
    }

    let stage: LiveSessionIssueStage
    let code: String
    let message: String
    let pendingEntry: TranscriptEntry?
    let impact: Impact

    init(
        stage: LiveSessionIssueStage,
        code: String = "pipeline.failure",
        message: String,
        pendingEntry: TranscriptEntry?,
        impact: Impact = .pipeline
    ) {
        self.stage = stage
        self.code = code
        self.message = message
        self.pendingEntry = pendingEntry
        self.impact = impact
    }

    var errorDescription: String? { message }
}

actor UtteranceProcessor {
    struct RecognizedInput: Sendable {
        let utterance: RecognizedUtterance
        let sourceSegmentSequence: UInt64
        let glossary: [GlossaryEntry]
        let sourceAudit: TranscriptSourceAudit
        let pronounGuidance: [TranslationPronounGuidance]
        let isFinalInSourceSegment: Bool
        let sourceDiscourseText: String
    }

    let dependencies: LiveSessionDependencies
    private var translationContext = TranslationContextWindow()
    var discourseContext = DiscourseContextWindow()
    var mode = TranslationMode.mandarinToEnglish

    init(dependencies: LiveSessionDependencies) {
        self.dependencies = dependencies
    }

    func resetContext() {
        translationContext.removeAll()
        discourseContext.removeAll()
    }

    func configure(mode: TranslationMode) {
        self.mode = mode
        resetContext()
    }

    func translate(_ input: RecognizedInput, sessionID: UUID) async throws -> TranscriptEntry {
        let translation = try await translate(input)
        let entry = try await makeEntry(
            recognition: input.utterance,
            translation: translation,
            sourceAudit: input.sourceAudit,
            sourceSegmentSequence: input.sourceSegmentSequence
        )
        try await persist(entry, sessionID: sessionID)
        if entry.translationReview == nil {
            translationContext.append(
                TranslationContextEntry(
                    sourceText: entry.sourceText,
                    targetText: entry.targetText
                )
            )
        }
        if input.isFinalInSourceSegment {
            discourseContext.append(
                VerifiedDiscourseTurn(
                    sequence: Int(clamping: input.sourceSegmentSequence),
                    text: input.sourceDiscourseText
                )
            )
        }
        await dependencies.transcript.append(entry)
        recordTranslationAfterCriticalPath(
            duration: translation.duration,
            review: translation.review
        )
        return entry
    }

    private func translate(_ input: RecognizedInput) async throws -> TranslationResult {
        do {
            let request = TranslationRequest(
                sourceText: input.utterance.text,
                sourceLanguage: mode.sourceLanguageTag,
                targetLanguage: mode.targetLanguageTag,
                glossary: matchedTerms(
                    in: input.utterance.text,
                    entries: input.glossary,
                    mode: mode
                ),
                context: translationContext.entries,
                pronounGuidance: input.pronounGuidance
            )
            return try await dependencies.translator.translate(request)
        } catch {
            if error is CancellationError { throw CancellationError() }
            throw failure(stage: .translation, error: error)
        }
    }

    func acceptSourceDiscourse(afterTerminalTranslation input: RecognizedInput) {
        guard input.isFinalInSourceSegment else { return }
        discourseContext.append(
            VerifiedDiscourseTurn(
                sequence: Int(clamping: input.sourceSegmentSequence),
                text: input.sourceDiscourseText
            )
        )
    }

}

extension UtteranceProcessor {
    func resolvedRecognition(
        _ normalized: (utterance: RecognizedUtterance, audit: TranscriptSourceAudit),
        sequence: Int,
        context: [VerifiedDiscourseTurn]
    ) -> ResolvedDiscourseUtterance {
        guard mode == .mandarinToEnglish else {
            return ResolvedDiscourseUtterance(
                utterance: normalized.utterance,
                audit: normalized.audit,
                pronounGuidance: []
            )
        }
        return resolveDiscourse(normalized, sequence: sequence, context: context)
    }

    private func persist(_ entry: TranscriptEntry, sessionID: UUID) async throws {
        do {
            try await dependencies.transcriptStore.append(entry, to: sessionID)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw failure(stage: .persistence, error: error, pendingEntry: entry)
        }
    }
}
