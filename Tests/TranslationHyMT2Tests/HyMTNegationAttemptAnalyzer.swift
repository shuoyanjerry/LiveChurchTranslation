import Foundation
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

enum HyMTNegationAttemptAnalyzer {
    static func analyze(
        observations: [HyMTNegationCompletionObservation],
        summary: HyMTQualificationAttemptSummary,
        request: TranslationRequest,
        configuration: HyMT2Configuration
    ) throws -> [HyMTNegationDiagnosticAttempt] {
        guard
            observations.count == summary.completionAttemptCount,
            observations.count == summary.outcomes.count,
            observations.count <= 2
        else {
            throw TranslationQualificationError.invalidReport(
                "diagnostic completion observations are inconsistent"
            )
        }
        let prepared = try preparedInput(request, configuration: configuration)
        let capability = retryCapability(observations.first?.output, prepared: prepared)
        return try observations.enumerated().map { index, observation in
            try makeAttempt(
                index: index,
                observation: observation,
                outcome: summary.outcomes[index],
                prepared: prepared,
                capability: capability
            )
        }
    }

    private static func preparedInput(
        _ request: TranslationRequest,
        configuration: HyMT2Configuration
    ) throws -> HyMT2PreparedTranslationInput {
        let input = HyMT2TranslationInputFactory.make(
            request,
            trimmedSource: request.sourceText.trimmingCharacters(in: .whitespacesAndNewlines),
            maximumGlossaryTerms: configuration.maximumGlossaryTerms
        )
        return try input.prepared(requestID: request.id)
    }

    private static func retryCapability(
        _ output: String?,
        prepared: HyMT2PreparedTranslationInput
    ) -> HyMT2FlatPronounRetryCapability? {
        guard
            let output,
            let plan = prepared.pronounPlan,
            let failure = failure(output, prepared: prepared)
        else { return nil }
        return HyMT2FlatPronounRetryAuthorizer.capability(
            for: output,
            plan: plan,
            failure: failure,
            source: prepared.source,
            requiredTerms: prepared.terms
        )
    }

    private static func makeAttempt(
        index: Int,
        observation: HyMTNegationCompletionObservation,
        outcome: String,
        prepared: HyMT2PreparedTranslationInput,
        capability: HyMT2FlatPronounRetryCapability?
    ) throws -> HyMTNegationDiagnosticAttempt {
        let phase: HyMTNegationDiagnosticAttemptPhase = index == 0 ? .initial : .strictRetry
        try require(outcome.hasPrefix(phase.rawValue + "."))
        let analysis = analyzeOutput(
            observation.output,
            prepared: prepared,
            capability: capability,
            strictRetry: phase == .strictRetry
        )
        return HyMTNegationDiagnosticAttempt(
            ordinal: index + 1,
            phase: phase,
            completionOutcome: outcome,
            targetCueClass: analysis.targetClass,
            validationIssueCodes: analysis.issueCodes,
            latencySeconds: observation.latencySeconds,
            outputAvailable: observation.output != nil,
            outputSHA256: TranslationQualificationSHA256.hash(
                data: Data((observation.output ?? "").utf8)
            )
        )
    }

    private static func require(_ condition: Bool) throws {
        guard condition else {
            throw TranslationQualificationError.invalidReport(
                "diagnostic completion phase is inconsistent"
            )
        }
    }
}
