import Foundation
import TranslationAPI
@testable import TranslationHyMT2

let pronounTestRequestID =
    UUID(
        uuidString: "11111111-2222-3333-4444-555555555555"
    ) ?? UUID()

func makePronounPlan(
    source: String,
    guidance: [TranslationPronounGuidance]
) throws -> HyMT2PronounPlan {
    guard
        let plan = try HyMT2PronounPlan.make(
            source: source,
            guidance: guidance,
            requestID: pronounTestRequestID
        )
    else {
        throw PronounTestSupportError.missingPlan
    }
    return plan
}

func anchored(
    _ plan: HyMT2PronounPlan,
    _ ordinal: Int,
    _ realization: String
) -> String {
    let occurrence = plan.occurrences[ordinal]
    return realization + occurrence.protectedBlock
}

func flatCertified(
    _ plan: HyMT2PronounPlan,
    _ ordinal: Int,
    _ realization: String
) -> String {
    let occurrence = plan.occurrences[ordinal]
    let resolution = HyMT2PronounResolutionToken.value(for: occurrence.resolution)
    return "\(realization) \(occurrence.identifier) \(resolution)"
}

func spacedCanonical(
    _ plan: HyMT2PronounPlan,
    _ ordinal: Int,
    _ realization: String
) -> String {
    let occurrence = plan.occurrences[ordinal]
    return "\(realization) \(occurrence.protectedBlock) "
}

func authorizedFlatRetryCapability(
    source: String,
    plan: HyMT2PronounPlan,
    initialOutput: String,
    requiredTerms: [TranslationTerm] = []
) throws -> HyMT2FlatPronounRetryCapability {
    do {
        _ = try HyMT2PronounMarkerParser.parse(initialOutput, plan: plan)
        throw PronounTestSupportError.expectedFailure
    } catch let failure as OutputValidationFailure {
        guard
            let capability = HyMT2FlatPronounRetryAuthorizer.capability(
                for: initialOutput,
                plan: plan,
                failure: failure,
                source: source,
                requiredTerms: requiredTerms
            )
        else {
            throw PronounTestSupportError.missingCapability
        }
        return capability
    }
}

func guidance(
    _ location: Int,
    _ resolution: TranslationPronounResolution,
    length: Int = 1
) -> TranslationPronounGuidance {
    TranslationPronounGuidance(
        sourceRange: TranslationSourceRange(location: location, length: length),
        resolution: resolution
    )
}

func validationIssues(
    output: String,
    source: String,
    plan: HyMT2PronounPlan
) -> [OutputValidationIssue] {
    do {
        _ = try HyMT2OutputValidator.validate(
            output,
            source: source,
            requiredTerms: [],
            pronounPlan: plan
        )
        return []
    } catch let failure as OutputValidationFailure {
        return failure.issues
    } catch {
        return []
    }
}

private enum PronounTestSupportError: Error {
    case expectedFailure
    case missingCapability
    case missingPlan
}
