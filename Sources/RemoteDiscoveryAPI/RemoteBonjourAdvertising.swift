import Foundation

public struct RemoteBonjourDescriptor: Equatable, Sendable {
    public let name: String
    public let type: String
    public let textRecord: Data

    public init(name: String, type: String, textRecord: Data) {
        self.name = name
        self.type = type
        self.textRecord = textRecord
    }
}

public protocol RemoteBonjourDescribing: Sendable {
    func descriptor() -> RemoteBonjourDescriptor
}
