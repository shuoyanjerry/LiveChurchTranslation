public protocol ModelRuntimeHealthChecking: Sendable {
    func isModelRuntimeReady() async -> Bool
}
