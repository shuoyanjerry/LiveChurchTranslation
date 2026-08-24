import Darwin
import Foundation
import RemotePairingAPI

public struct RemotePeerAddress: Equatable, Sendable {
    public let host: String

    public init(host: String) {
        self.host = host
    }

    public var isPrivateLinkLocalOrLoopback: Bool {
        checkIPv4(normalizedHost) || checkIPv6(normalizedHost)
    }

    public var pairingClientBinding: RemotePairingClientBinding? {
        guard checkIPv4(normalizedHost) || checkIPv6(normalizedHost) else { return nil }
        return RemotePairingClientBinding(rawValue: normalizedHost)
    }

    private var normalizedHost: String {
        let plainHost =
            host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .split(separator: "%", maxSplits: 1).first.map(String.init) ?? host
        if let address = canonicalIPv4(plainHost) { return address }
        if let address = canonicalIPv6(plainHost) { return address }
        return plainHost.lowercased()
    }

    private func canonicalIPv4(_ value: String) -> String? {
        var address = in_addr()
        guard inet_pton(AF_INET, value, &address) == 1 else { return nil }
        let bytes = withUnsafeBytes(of: address.s_addr, Array.init)
        return bytes.map(String.init).joined(separator: ".")
    }

    private func canonicalIPv6(_ value: String) -> String? {
        var address = in6_addr()
        guard inet_pton(AF_INET6, value, &address) == 1 else { return nil }
        let bytes = withUnsafeBytes(of: address.__u6_addr.__u6_addr8, Array.init)
        if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
            return bytes.suffix(4).map(String.init).joined(separator: ".")
        }
        var output = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        guard inet_ntop(AF_INET6, &address, &output, socklen_t(output.count)) != nil else {
            return nil
        }
        let outputBytes = output.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(bytes: outputBytes, encoding: .utf8)?.lowercased()
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
