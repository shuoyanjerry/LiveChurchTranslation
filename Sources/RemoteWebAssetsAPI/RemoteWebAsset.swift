import Foundation

public struct RemoteWebAsset: Equatable, Sendable {
    public let contentType: String
    public let body: Data

    public init(contentType: String, body: Data) {
        self.contentType = contentType
        self.body = body
    }
}

public protocol RemoteWebAssetProviding: Sendable {
    func asset(for requestPath: String) -> RemoteWebAsset?
}
