import Foundation
import TranslationAPI

struct HyMT2PronounDiagnosticObservation: Equatable, Sendable {
    let requestID: UUID
    let phase: HyMT2AttemptPhase
    let sourceRange: TranslationSourceRange
    let expectedResolution: TranslationPronounResolution
    let observedClass: HyMT2ObservedPronounClass
}

protocol HyMT2PronounDiagnosticObserving: Sendable {
    func record(_ observation: HyMT2PronounDiagnosticObservation) async
}

struct HyMT2NoOpPronounDiagnosticObserver: HyMT2PronounDiagnosticObserving {
    func record(_: HyMT2PronounDiagnosticObservation) async {}
}

struct HyMT2PronounDiagnosticValue: Equatable, Sendable {
    let sourceRange: TranslationSourceRange
    let expectedResolution: TranslationPronounResolution
    let observedClass: HyMT2ObservedPronounClass
}

extension OutputValidationIssue {
    var pronounDiagnostic: HyMT2PronounDiagnosticValue? {
        switch self {
        case .missingPronounMarker(_, let range, let expected):
            HyMT2PronounDiagnosticValue(
                sourceRange: range,
                expectedResolution: expected,
                observedClass: .missing
            )
        case .wrongPronounRealization(_, let range, let expected, let observed):
            HyMT2PronounDiagnosticValue(
                sourceRange: range,
                expectedResolution: expected,
                observedClass: observed
            )
        default:
            nil
        }
    }
}
