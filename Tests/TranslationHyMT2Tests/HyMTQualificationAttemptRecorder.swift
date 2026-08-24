import Foundation
@testable import TranslationHyMT2

actor HyMTQualificationAttemptRecorder: HyMT2AttemptObserving {
    private var observations: [UUID: [HyMT2AttemptObservation]] = [:]

    func record(_ observation: HyMT2AttemptObservation) {
        observations[observation.requestID, default: []].append(observation)
    }

    func takeSummary(for requestID: UUID) -> HyMTQualificationAttemptSummary {
        let values = observations.removeValue(forKey: requestID) ?? []
        return HyMTQualificationAttemptSummary(
            completionAttemptCount: values.count,
            strictRetryUsed: values.contains { $0.phase == .strictRetry },
            safetyFallbackUsed: values.contains { $0.phase == .safetyFallback },
            outcomes: values.map { "\($0.phase.rawValue).\($0.outcome.rawValue)" }
        )
    }
}

struct HyMTQualificationAttemptSummary: Equatable, Sendable {
    let completionAttemptCount: Int
    let strictRetryUsed: Bool
    let safetyFallbackUsed: Bool
    let outcomes: [String]
}
