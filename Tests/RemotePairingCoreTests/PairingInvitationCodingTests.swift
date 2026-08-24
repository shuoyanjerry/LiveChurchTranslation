import Foundation
import RemotePairingAPI
import RemoteSharingAPI
import Testing

@Suite("Pairing invitation coding")
struct PairingInvitationCodingTests {
    @Test("Viewer output omits a fake expiry while legacy operator data decodes")
    func sessionLifetimeCodingContract() throws {
        let viewer = PairingInvitation(
            id: UUID(),
            role: .viewer,
            fragmentCredential: String(repeating: "v", count: 43),
            expiresAt: nil
        )
        let encoded = try JSONEncoder().encode(viewer)
        let json = try #require(String(bytes: encoded, encoding: .utf8))
        #expect(!json.contains("expiresAt"))
        #expect(try JSONDecoder().decode(PairingInvitation.self, from: encoded) == viewer)

        let operatorInvitation = PairingInvitation(
            id: UUID(),
            role: .operator,
            fragmentCredential: String(repeating: "o", count: 43),
            expiresAt: Date(timeIntervalSince1970: 3_600)
        )
        let legacyData = try JSONEncoder().encode(operatorInvitation)
        #expect(
            try JSONDecoder().decode(PairingInvitation.self, from: legacyData)
                == operatorInvitation
        )
    }
}
