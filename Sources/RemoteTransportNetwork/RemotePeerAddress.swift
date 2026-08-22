import Darwin
import Foundation

public struct RemotePeerAddress: Equatable, Sendable {
    public let host: String

    public init(host: String) {
        self.host = host
    }

    public var isPrivateLinkLocalOrLoopback: Bool {
        let plainHost =
            host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .split(separator: "%", maxSplits: 1).first.map(String.init) ?? host
        return checkIPv4(plainHost) || checkIPv6(plainHost)
    }

    private func checkIPv4(_ value: String) -> Bool {
        var address = in_addr()
        guard inet_pton(AF_INET, value, &address) == 1 else { return false }
        let bytes = withUnsafeBytes(of: address.s_addr, Array.init)
        return bytes[0] == 10
            || bytes[0] == 127
            || (bytes[0] == 169 && bytes[1] == 254)
            || (bytes[0] == 172 && (16...31).contains(bytes[1]))
            || (bytes[0] == 192 && bytes[1] == 168)
    }

    private func checkIPv6(_ value: String) -> Bool {
        var address = in6_addr()
        guard inet_pton(AF_INET6, value, &address) == 1 else { return false }
        let bytes = withUnsafeBytes(of: address.__u6_addr.__u6_addr8, Array.init)
        let isLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
        let isUniqueLocal = bytes[0] & 0xFE == 0xFC
        let isLinkLocal = bytes[0] == 0xFE && bytes[1] & 0xC0 == 0x80
        return isLoopback || isUniqueLocal || isLinkLocal
    }
}
