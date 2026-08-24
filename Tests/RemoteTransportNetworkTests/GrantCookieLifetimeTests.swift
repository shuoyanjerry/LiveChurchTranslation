import RemoteTransportNetwork
import Testing

@Suite("Remote grant cookie lifetime")
struct GrantCookieLifetimeTests {
    @Test("Viewer grants use a browser-session cookie without a fake expiry")
    func viewerSessionCookie() {
        let header = RemoteGrantCookie.header(
            credential: String(repeating: "v", count: 43),
            maxAge: nil,
            secure: false
        )
        #expect(!header.contains("Max-Age="))
        #expect(header.contains("HttpOnly"))
        #expect(header.contains("SameSite=Strict"))
    }

    @Test("Expiring operator grants retain an explicit maximum age")
    func operatorPersistentCookie() {
        let header = RemoteGrantCookie.header(
            credential: String(repeating: "o", count: 43),
            maxAge: 120,
            secure: true
        )
        #expect(header.contains("Max-Age=120"))
        #expect(header.contains("Secure"))
    }
}
