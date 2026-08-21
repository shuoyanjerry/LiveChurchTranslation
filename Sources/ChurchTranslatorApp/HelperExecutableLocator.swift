import Foundation

enum HelperExecutableLocator {
    static func llamaServer(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL {
        if let override = environment["LIVE_CHURCH_LLAMA_SERVER"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return bundle.bundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Helpers", directoryHint: .isDirectory)
            .appending(path: "llama-server")
    }
}
