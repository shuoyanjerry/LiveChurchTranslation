import Foundation
import VADAPI

struct V3SelectedVADTraceCounter {
    private(set) var reached: [String: Int] = [:]
    private(set) var resolutions: [String: Int] = [:]

    mutating func append(_ events: [CandidatePauseTraceEvent]) {
        for event in events {
            switch event {
            case .reached(let value):
                reached[String(value.checkpoint.threshold.rawValue), default: 0] += 1
            case .resolved(let value):
                resolutions[resolutionName(value.reason), default: 0] += 1
            }
        }
    }

    private func resolutionName(_ value: CandidatePauseResolutionReason) -> String {
        switch value {
        case .speechResumed:
            "speechResumed"
        case .segmentEnded(let reason):
            "segmentEnded.\(reason.v3Name)"
        }
    }
}
