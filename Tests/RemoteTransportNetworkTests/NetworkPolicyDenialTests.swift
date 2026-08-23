@preconcurrency import Network
@testable import RemoteTransportNetwork
import Testing

@Suite struct NetworkPolicyDenialTests {
    @Test func dnsPolicyDenialIsRecognized() {
        let error = NWError.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))

        #expect(NWLocalNetworkPermissionDenial.matches(error))
    }

    @Test func ordinaryPortAndDnsFailuresAreNotPermissionDenials() {
        #expect(!NWLocalNetworkPermissionDenial.matches(.posix(.EADDRINUSE)))
        #expect(
            !NWLocalNetworkPermissionDenial.matches(
                .dns(DNSServiceErrorType(kDNSServiceErr_NoError))
            )
        )
    }
}
