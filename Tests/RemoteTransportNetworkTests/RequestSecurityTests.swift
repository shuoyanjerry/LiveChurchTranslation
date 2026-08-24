import Foundation
import RemoteTransportNetwork
import Testing

@Suite("Remote request security")
struct RequestSecurityTests {
    @Test("Only local peers and exact Host and Origin values pass")
    func localAndSameOrigin() throws {
        let policy = RequestSecurityPolicy(
            configuration: .init(
                allowedHosts: ["reader.local:9000"],
                allowedOrigins: ["http://reader.local:9000"]
            ))
        let request = makeRequest(headers: [
            "host": ["reader.local:9000"],
            "origin": ["http://reader.local:9000"],
        ])
        try policy.validateMutation(request, peer: .init(host: "192.168.1.20"))
        #expect(throws: RemoteTransportError.nonLocalPeer) {
            try policy.validateMutation(request, peer: .init(host: "8.8.8.8"))
        }
        let rebound = makeRequest(headers: [
            "host": ["attacker.test:9000"],
            "origin": ["http://attacker.test:9000"],
        ])
        #expect(throws: RemoteTransportError.invalidHost) {
            try policy.validateMutation(rebound, peer: .init(host: "192.168.1.20"))
        }
    }

    @Test("Credentials are equivalent in bearer and HttpOnly-cookie forms")
    func authenticationParity() throws {
        let token = String(repeating: "A", count: 43)
        let cookie = makeRequest(headers: ["cookie": ["church_remote=\(token)"]])
        let bearer = makeRequest(headers: ["authorization": ["Bearer \(token)"]])
        #expect(try RemoteCredentialExtractor.credential(from: cookie) == token)
        #expect(try RemoteCredentialExtractor.credential(from: bearer) == token)
    }

    @Test("Client bindings use only normalized, server-observed IP addresses")
    func clientBindingNormalization() throws {
        let ipv4 = try #require(RemotePeerAddress(host: "192.168.1.20").pairingClientBinding)
        let ipv6 = try #require(RemotePeerAddress(host: "[fe80::1234%en0]").pairingClientBinding)
        let mapped = try #require(
            RemotePeerAddress(host: "::ffff:192.168.1.20").pairingClientBinding
        )

        #expect(ipv4.rawValue == "192.168.1.20")
        #expect(ipv6.rawValue == "fe80::1234")
        #expect(mapped == ipv4)
        #expect(ipv4.description == "<redacted>")
        #expect(RemotePeerAddress(host: "reader.example").pairingClientBinding == nil)
    }

    @Test("Every response receives browser hardening headers")
    func responseHeaders() {
        let headers = SecureResponseHeaders.applying()
        #expect(headers["Cache-Control"]?.contains("no-store") == true)
        #expect(headers["Pragma"] == "no-cache")
        #expect(headers["Expires"] == "0")
        #expect(headers["Content-Security-Policy"]?.contains("frame-ancestors 'none'") == true)
        #expect(headers["X-Content-Type-Options"] == "nosniff")
        #expect(headers["Cross-Origin-Opener-Policy"] == "same-origin")
        #expect(headers["Cross-Origin-Resource-Policy"] == "same-origin")
        #expect(headers["X-Permitted-Cross-Domain-Policies"] == "none")
    }

    private func makeRequest(headers: [String: [String]]) -> RemoteHTTPRequest {
        RemoteHTTPRequest(
            method: "POST",
            target: "/api/control",
            path: "/api/control",
            query: nil,
            headers: headers,
            body: Data()
        )
    }
}
