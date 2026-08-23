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

    @Test func unresolvedPronounNoticeIsHiddenWhenThereAreNoUnresolvedDecisions() {
        #expect(UnresolvedPronounNotice(unresolvedCount: 0) == nil)
    }

    @Test func unresolvedPronounNoticeUsesRestrainedSingularCopy() throws {
        let notice = try #require(UnresolvedPronounNotice(unresolvedCount: 1))

        #expect(notice.text == "Pronoun context unresolved · neutral English")
        #expect(
            notice.accessibilityLabel
                == "One spoken Mandarin pronoun remains unresolved. Neutral English was used."
        )
    }

    @Test func unresolvedPronounNoticeCountsMultipleDecisions() throws {
        let notice = try #require(UnresolvedPronounNotice(unresolvedCount: 3))

        #expect(notice.text == "3 pronoun contexts unresolved · neutral English")
        #expect(
            notice.accessibilityLabel
                == "3 spoken Mandarin pronouns remain unresolved. Neutral English was used."
        )
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

    @Test func localSharingCopyDisclosesScopeAndTransportRisk() {
        #expect(
            LocalSharingPresentation.subtitle
                == "Nearby devices can read the live transcript and translation."
        )
        #expect(
            LocalSharingPresentation.transportWarning
                == "Trusted local network only · Traffic is not encrypted"
        )
    }

    @Test func localSharingOffersOnlyViewerInvitations() {
        #expect(LocalSharingPresentation.invitationRole == .viewer)

        let viewerInvitation = LocalSharingInvitation(
            role: .viewer,
            url: URL(string: "http://quiet-reader.local:8123/#invite=viewer")!,
            expiresAt: Date(timeIntervalSince1970: 1_800)
        )
        let operatorInvitation = LocalSharingInvitation(
            role: .operator,
            url: URL(string: "http://quiet-reader.local:8123/#invite=operator")!,
            expiresAt: Date(timeIntervalSince1970: 1_800)
        )

        #expect(LocalSharingPresentation.visibleInvitation(viewerInvitation) == viewerInvitation)
        #expect(LocalSharingPresentation.visibleInvitation(operatorInvitation) == nil)
    }
}
