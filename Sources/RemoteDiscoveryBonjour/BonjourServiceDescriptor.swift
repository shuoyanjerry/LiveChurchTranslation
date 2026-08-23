import Foundation
import RemoteDiscoveryAPI

public struct BonjourServiceDescriptor: Equatable, Sendable, RemoteBonjourDescribing {
    public static let serviceType = "_churchtranslate._tcp"

    public let name: String
    public let protocolVersion: UInt16

    public init(name: String = "教会实时翻译", protocolVersion: UInt16 = 1) {
        self.name = String(name.prefix(63))
        self.protocolVersion = protocolVersion
    }

    public var textRecord: Data {
        DNSTextRecord.encode([
            "pairing": "required",
            "product": "quiet-liturgy",
            "v": String(protocolVersion),
        ])
    }

    public func descriptor() -> RemoteBonjourDescriptor {
        RemoteBonjourDescriptor(name: name, type: Self.serviceType, textRecord: textRecord)
    }
}

enum DNSTextRecord {
    static func encode(_ values: [String: String]) -> Data {
        var result = Data()
        for (key, value) in values.sorted(by: { $0.key < $1.key }) {
            let bytes = Data("\(key)=\(value)".utf8.prefix(255))
            result.append(UInt8(bytes.count))
            result.append(bytes)
        }
        return result
    }
}
