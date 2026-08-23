import TranslationAPI

struct HyMT2FlatPronounRetryCapability: Sendable {
    fileprivate let authorizedPlan: HyMT2PronounPlan

    func authorizes(_ plan: HyMT2PronounPlan) -> Bool {
        authorizedPlan == plan
    }
}

enum HyMT2FlatPronounRetryAuthorizer {
    static func capability(
        for initialOutput: String,
        plan: HyMT2PronounPlan,
        failure: OutputValidationFailure,
        source: String,
        requiredTerms: [TranslationTerm]
    ) -> HyMT2FlatPronounRetryCapability? {
        guard isBindingOnly(failure.issues) else { return nil }
        do {
            _ = try HyMT2PronounMarkerParser.parse(initialOutput, plan: plan)
            return nil
        } catch let verifiedFailure as OutputValidationFailure {
            guard verifiedFailure.issues == failure.issues,
                isBindingOnly(verifiedFailure.issues)
            else { return nil }
            guard
                let target =
                    try? HyMT2PronounMarkerParser
                    .cleanTargetAfterSurfaceValidation(initialOutput, plan: plan)
            else { return nil }
            guard
                HyMT2FidelityValidator.issues(
                    target: target,
                    source: source,
                    requiredTerms: requiredTerms
                ).isEmpty
            else { return nil }
            return HyMT2FlatPronounRetryCapability(authorizedPlan: plan)
        } catch {
            return nil
        }
    }

    private static func isBindingOnly(_ issues: [OutputValidationIssue]) -> Bool {
        !issues.isEmpty
            && issues.allSatisfy { issue in
                switch issue {
                case .reusedPronounRealization, .wrongPronounRealization:
                    true
                default:
                    false
                }
            }
    }
}
