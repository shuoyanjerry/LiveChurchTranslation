import Foundation
import TranslationAPI

struct HyMT2PronounTraceObservation: Equatable, Sendable {
    let requestID: UUID
    let phase: HyMT2AttemptPhase
    let sourceRange: TranslationSourceRange
    let resolution: TranslationPronounResolution
    let realizationClass: HyMT2PronounRealizationClass
}

protocol HyMT2PronounTraceObserving: Sendable {
    func record(_ observation: HyMT2PronounTraceObservation) async
}

struct HyMT2NoOpPronounTraceObserver: HyMT2PronounTraceObserving {
    func record(_: HyMT2PronounTraceObservation) async {}
}
