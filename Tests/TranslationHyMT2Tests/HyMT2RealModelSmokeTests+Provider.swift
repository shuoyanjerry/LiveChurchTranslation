import Foundation
@testable import TranslationHyMT2

extension HyMT2RealModelSmokeTests {
    func loadedProvider(
        environment: [String: String]
    ) async throws -> HyMT2TranslationProvider? {
        guard
            let modelPath = environment["HYMT_MODEL_DIR"],
            let helperPath = environment["HYMT_LLAMA_SERVER"]
        else { return nil }
        try requireExisting(modelPath)
        try requireExisting(helperPath)
        let provider = HyMT2TranslationProvider(
            helperExecutableURL: URL(fileURLWithPath: helperPath)
        )
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))
        return provider
    }

    private func requireExisting(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
    }
}
