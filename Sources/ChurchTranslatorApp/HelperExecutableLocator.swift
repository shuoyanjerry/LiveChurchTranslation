import Foundation

enum HelperExecutableLocator {
    static func llamaServer(bundle: Bundle = .main) -> URL {
        return bundle.bundleURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "MacOS", directoryHint: .isDirectory)
            .appending(path: "llama-server")
    }
}
