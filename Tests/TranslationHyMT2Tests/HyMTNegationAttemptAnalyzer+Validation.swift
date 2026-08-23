@testable import TranslationHyMT2

extension HyMTNegationAttemptAnalyzer {
    static func analyzeOutput(
        _ output: String?,
        prepared: HyMT2PreparedTranslationInput,
        capability: HyMT2FlatPronounRetryCapability?,
        strictRetry: Bool
    ) -> (targetClass: HyMTNegationTargetCueClass, issueCodes: [HyMTNegationDiagnosticIssueCode]) {
        guard let output else { return (.none, [.transportFailure]) }
        do {
            _ = try HyMT2OutputValidator.validated(
                output,
                source: prepared.source,
                requiredTerms: prepared.terms,
                pronounPlan: prepared.pronounPlan,
                flatRetryCapability: strictRetry ? capability : nil,
                strictRetry: strictRetry
            )
            return (HyMTNegationCueClassifier.targetClass(output), [])
        } catch let failure as OutputValidationFailure {
            return (
                HyMTNegationCueClassifier.targetClass(output),
                HyMTNegationDiagnosticIssueMapper.codes(failure.issues)
            )
        } catch {
            return (
                HyMTNegationCueClassifier.targetClass(output),
                [.unexpectedValidationError]
            )
        }
    }

    static func failure(
        _ output: String,
        prepared: HyMT2PreparedTranslationInput
    ) -> OutputValidationFailure? {
        do {
            _ = try HyMT2OutputValidator.validated(
                output,
                source: prepared.source,
                requiredTerms: prepared.terms,
                pronounPlan: prepared.pronounPlan
            )
            return nil
        } catch let failure as OutputValidationFailure {
            return failure
        } catch {
            return nil
        }
    }
}
