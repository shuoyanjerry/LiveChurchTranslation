import Foundation
import TranslationAPI

struct HyMT2TranslationExecutor: Sendable {
    let configuration: HyMT2Configuration
    let transport: any LlamaServerTransport
    let attemptObserver: any HyMT2AttemptObserving
    let pronounTraceObserver: any HyMT2PronounTraceObserving
    let pronounDiagnosticObserver: any HyMT2PronounDiagnosticObserving
}
