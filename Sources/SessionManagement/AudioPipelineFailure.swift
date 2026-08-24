import Foundation

struct AudioPipelineFailure: LocalizedError, Sendable {
    enum Stage: Int, Sendable {
        case recording = 0
        case capture = 1
        case processing = 2
    }

    let stage: Stage
    let message: String

    var errorDescription: String? { message }
}
