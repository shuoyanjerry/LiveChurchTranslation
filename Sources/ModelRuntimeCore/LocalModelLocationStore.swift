import Foundation
import ModelRuntimeAPI

public actor LocalModelLocationStore: ModelLocationStore {
    private let root: URL
    private let fileManager: FileManager
    private var locations: [ModelID: URL] = [:]

    public init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    public func location(for modelID: ModelID) async -> URL? {
        if let cached = locations[modelID], isValidDirectory(cached) { return cached }
        let candidate = root.appending(path: modelID.rawValue, directoryHint: .isDirectory)
        guard isValidDirectory(candidate) else { return nil }
        locations[modelID] = candidate
        return candidate
    }

    public func register(_ location: URL, for modelID: ModelID) async throws {
        guard isValidDirectory(location) else {
            throw CocoaError(.fileNoSuchFile)
        }
        locations[modelID] = location
    }

    public func removeLocation(for modelID: ModelID) async throws {
        locations.removeValue(forKey: modelID)
    }

    private func isValidDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
