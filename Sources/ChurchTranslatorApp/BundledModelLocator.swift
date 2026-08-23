import Foundation

enum BundledModelLocator {
    static func modelsRoot(in bundle: Bundle = .main) -> URL? {
        bundle.resourceURL?.appending(path: "Models", directoryHint: .isDirectory)
    }
}
