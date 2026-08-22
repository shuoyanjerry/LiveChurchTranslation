import Foundation
@testable import LiveReader
import RemoteSharingFeatureAPI
import Testing

@Suite struct TranscriptPresentationTests {
    @Test func timestampUsesStableHourMinuteSecondFormat() {
        #expect(TranscriptTimestamp.format(milliseconds: 135_999) == "00:02:15")
        #expect(TranscriptTimestamp.format(milliseconds: 3_661_000) == "01:01:01")
    }

    @Test func timestampClampsInvalidNegativeOffsets() {
        #expect(TranscriptTimestamp.format(milliseconds: -1_000) == "00:00:00")
    }

    @Test func sharingStateCarriesOnlyImmutablePresentationValues() {
        let peer = LocalSharingPeer(
            id: "sanctuary-ipad",
            name: "Sanctuary iPad",
            role: .viewer
        )
        let expiry = Date(timeIntervalSince1970: 1_800)
        let endpoint = URL(string: "http://quiet-reader.local:8123")!
        let invitation = LocalSharingInvitation(
            role: .viewer,
            url: URL(string: "http://quiet-reader.local:8123/#invite=redacted")!,
            expiresAt: expiry
        )
        let state = LocalSharingViewState.on(
            endpoint: endpoint,
            connectionCount: 1,
            invitation: invitation,
            peers: [peer]
        )

        #expect(
            state
                == .on(
                    endpoint: endpoint,
                    connectionCount: 1,
                    invitation: invitation,
                    peers: [peer]
                )
        )
    }
}
