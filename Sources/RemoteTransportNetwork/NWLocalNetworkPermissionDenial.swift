@preconcurrency import Network

enum NWLocalNetworkPermissionDenial {
    static func matches(_ error: NWError) -> Bool {
        guard case .dns(let code) = error else { return false }
        return code == DNSServiceErrorType(kDNSServiceErr_PolicyDenied)
    }
}
