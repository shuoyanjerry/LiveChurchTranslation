import DiscourseResolutionAPI
import DiscourseResolutionCore
import Foundation
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

struct HyMTQualificationRunner {
    let provider: HyMT2TranslationProvider
    let recorder: HyMTQualificationAttemptRecorder
    let pronounTraceRecorder: HyMTQualificationPronounTraceRecorder
    let maximumGlossaryTerms: Int
    private let resolver = DiscourseResolver()
    private let requestIDFactory: @Sendable () -> UUID

    init(
        provider: HyMT2TranslationProvider,
        recorder: HyMTQualificationAttemptRecorder,
        pronounTraceRecorder: HyMTQualificationPronounTraceRecorder,
        maximumGlossaryTerms: Int = HyMT2Configuration().maximumGlossaryTerms,
        requestIDFactory: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.provider = provider
        self.recorder = recorder
        self.pronounTraceRecorder = pronounTraceRecorder
        self.maximumGlossaryTerms = maximumGlossaryTerms
        self.requestIDFactory = requestIDFactory
    }

    func run(
        _ corpus: TranslationQualificationCorpus
    ) async throws -> [TranslationQualificationAttempt] {
        try await run(segments: corpus.manifest.segments)
    }

    func run(
        segments: [TranslationQualificationSegment]
    ) async throws -> [TranslationQualificationAttempt] {
        try HyMTQualificationGlossary.requireManifestCoverage(
            segments,
            limit: maximumGlossaryTerms
        )
        var context = HyMTQualificationContext()
        var attempts: [TranslationQualificationAttempt] = []
        for segment in segments {
            try Task.checkCancellation()
            let recent = context.latest(for: segment.sourceID)
            let result = try await evaluate(segment, recent: recent)
            attempts.append(result.attempt)
            if let persisted = result.persisted {
                context.append(persisted, sourceID: segment.sourceID)
            }
        }
        return attempts
    }
}

extension HyMTQualificationRunner {
    private func evaluate(
        _ segment: TranslationQualificationSegment,
        recent: [HyMTQualificationPersistedTurn]
    ) async throws -> HyMTQualificationSegmentResult {
        let resolution = resolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: segment.sequence,
                currentText: segment.observedASRAmbiguousChinese,
                verifiedTurns: recent.discourseTurns
            )
        )
        let request = requestFor(
            id: requestIDFactory(),
            source: resolution.resolvedText,
            context: recent,
            guidance: resolution.pronounGuidance
        )
        let termExpectations = try termExpectations(for: request, segment: segment)
        let outcome = try await translate(request)
        let input = await attemptInput(
            segment: segment,
            recent: recent,
            resolution: resolution,
            evaluation: HyMTQualificationAttemptEvaluation(
                request: request,
                termExpectations: termExpectations,
                outcome: outcome
            )
        )
        let attempt = HyMTQualificationAttemptFactory.make(input)
        let persisted =
            TranslationQualificationCompletionPolicy.approvesContext(attempt)
            ? persistedTurn(segment, source: resolution.resolvedText, outcome: outcome)
            : nil
        return HyMTQualificationSegmentResult(attempt: attempt, persisted: persisted)
    }

    private func persistedTurn(
        _ segment: TranslationQualificationSegment,
        source: String,
        outcome: HyMTQualificationOutcome
    ) -> HyMTQualificationPersistedTurn? {
        outcome.hypothesis.map {
            HyMTQualificationPersistedTurn(
                segmentID: segment.id,
                sequence: segment.sequence,
                sourceText: source,
                targetText: $0
            )
        }
    }

    private func requestFor(
        id: UUID,
        source: String,
        context: [HyMTQualificationPersistedTurn],
        guidance: [DiscoursePronounGuidance]
    ) -> TranslationRequest {
        TranslationRequest(
            id: id,
            sourceText: source,
            glossary: HyMTQualificationGlossary.matchedTerms(in: source),
            context: context.translationEntries,
            pronounGuidance: HyMTQualificationGuidanceMapper.translationGuidance(guidance)
        )
    }

    private func translate(_ request: TranslationRequest) async throws -> HyMTQualificationOutcome {
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let result = try await provider.translate(request)
            return HyMTQualificationOutcome(
                hypothesis: result.targetText,
                latencySeconds: seconds(started.duration(to: clock.now)),
                backendReviewIssueCodes: result.review?.issueCodes ?? [],
                error: nil
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return HyMTQualificationOutcome(
                hypothesis: nil,
                latencySeconds: seconds(started.duration(to: clock.now)),
                backendReviewIssueCodes: [],
                error: error
            )
        }
    }

    private func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

struct HyMTQualificationOutcome {
    let hypothesis: String?
    let latencySeconds: Double
    let backendReviewIssueCodes: [String]
    let error: (any Error)?
}

struct HyMTQualificationSegmentResult {
    let attempt: TranslationQualificationAttempt
    let persisted: HyMTQualificationPersistedTurn?
}
