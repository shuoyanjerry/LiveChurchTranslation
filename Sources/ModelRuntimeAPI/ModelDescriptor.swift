import Foundation

public struct ModelID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct ModelDescriptor: Codable, Equatable, Sendable {
    public let id: ModelID
    public let displayName: String
    public let version: String
    public let expectedBytes: Int64
    public let sha256: String?
    public let license: String

    public init(
        id: ModelID,
        displayName: String,
        version: String,
        expectedBytes: Int64,
        sha256: String?,
        license: String
    ) {
        self.id = id
        self.displayName = displayName
        self.version = version
        self.expectedBytes = expectedBytes
        self.sha256 = sha256
        self.license = license
    }
}

public enum ModelRuntimeState: Equatable, Sendable {
    case missing
    case downloading(progress: Double)
    case available(location: URL)
    case loading
    case ready
    case failed(message: String)
}

public struct ModelRuntimeStatus: Equatable, Sendable {
    public let descriptor: ModelDescriptor
    public let state: ModelRuntimeState

    public init(descriptor: ModelDescriptor, state: ModelRuntimeState) {
        self.descriptor = descriptor
        self.state = state
    }
}
