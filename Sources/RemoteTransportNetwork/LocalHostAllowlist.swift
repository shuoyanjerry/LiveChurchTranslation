import Darwin
import Foundation

enum LocalHostAllowlist {
    static func make(advertisedHost: String, port: UInt16) -> RequestSecurityConfiguration {
        var names = Set([advertisedHost.lowercased(), "localhost", "127.0.0.1", "[::1]"])
        names.formUnion(interfaceIPv4Addresses())
        let hosts = Set(names.map { "\($0):\(port)" })
        let origins = Set(hosts.map { "http://\($0)" })
        return RequestSecurityConfiguration(allowedHosts: hosts, allowedOrigins: origins)
    }

    private static func interfaceIPv4Addresses() -> Set<String> {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }
        var result = Set<String>()
        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let interface = current?.pointee {
            defer { current = interface.ifa_next }
            guard let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }
            var storage = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            if getnameinfo(address, length, &storage, socklen_t(storage.count), nil, 0, NI_NUMERICHOST) == 0 {
                let bytes = storage.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                if let host = String(bytes: bytes, encoding: .utf8) {
                    result.insert(host)
                }
            }
        }
        return result
    }
}
