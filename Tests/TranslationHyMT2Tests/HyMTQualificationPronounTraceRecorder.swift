import Foundation
@testable import TranslationHyMT2

actor HyMTQualificationPronounTraceRecorder: HyMT2PronounTraceObserving {
    private var observations: [UUID: [HyMT2PronounTraceObservation]] = [:]

    func record(_ observation: HyMT2PronounTraceObservation) {
        observations[observation.requestID, default: []].append(observation)
    }

    func take(for requestID: UUID) -> [HyMT2PronounTraceObservation] {
        observations.removeValue(forKey: requestID) ?? []
    }
}
