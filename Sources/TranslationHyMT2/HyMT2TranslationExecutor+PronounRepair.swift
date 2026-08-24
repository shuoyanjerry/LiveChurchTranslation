import Foundation

extension HyMT2TranslationExecutor {
    func auditedPronounRepairCandidate(
        _ output: String,
        input: HyMT2PreparedTranslationInput,
        requestID: UUID,
        phase: HyMT2AttemptPhase,
        flatRetryCapability: HyMT2FlatPronounRetryCapability? = nil
    ) async -> String {
        let repaired = HyMT2PronounDeterministicRepairer.repair(
            output,
            plan: input.pronounPlan
        )
        guard repaired != output else { return output }
        do {
            _ = try validate(
                output,
                input: input,
                flatRetryCapability: flatRetryCapability,
                strictRetry: phase == .strictRetry
            )
        } catch let originalFailure as OutputValidationFailure {
            await recordPronounDiagnostics(
                originalFailure,
                requestID: requestID,
                phase: phase
            )
        } catch {
            return output
        }
        return repaired
    }
}
