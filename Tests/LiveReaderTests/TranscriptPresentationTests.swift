import Foundation
@testable import LiveReader
import RemoteSharingFeatureAPI
import SessionManagementAPI
import Testing

@Suite struct TranscriptPresentationTests {
    @Test func timestampUsesStableHourMinuteSecondFormat() {
        #expect(TranscriptTimestamp.format(milliseconds: 135_999) == "00:02:15")
        #expect(TranscriptTimestamp.format(milliseconds: 3_661_000) == "01:01:01")
    }

    @Test func timestampClampsInvalidNegativeOffsets() {
        #expect(TranscriptTimestamp.format(milliseconds: -1_000) == "00:00:00")
    }

    @Test func liveStatusDescribesTheCurrentPipelineStage() {
        #expect(LiveSessionStatusPresentation.label(for: .listening) == "正在聆听")
        #expect(LiveSessionStatusPresentation.label(for: .recognizing) == "正在识别")
        #expect(LiveSessionStatusPresentation.label(for: .translating) == "正在翻译")
        #expect(LiveSessionStatusPresentation.label(for: .stopping) == "正在完成")
    }

    @Test func libraryAudioUsesAUserFacingStorageDescription() {
        #expect(LibraryAudioPresentation.storageLabel == "已保存在这台 Mac 上")
        #expect(!LibraryAudioPresentation.storageLabel.contains("recording.caf"))
    }

    @Test func sharingStateCarriesOnlyImmutablePresentationValues() {
        let peer = LocalSharingPeer(
            id: "sanctuary-ipad",
            name: "Sanctuary iPad",
            role: .viewer
        )
        let endpoint = URL(string: "http://live-church-translation.local:8123")!
        let invitation = LocalSharingInvitation(
            role: .viewer,
            url: URL(string: "http://live-church-translation.local:8123/#invite=redacted")!
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

    @Test func localSharingCopyIsConciseAndChineseFirst() {
        #expect(
            LocalSharingPresentation.subtitle
                == "听众需连接同一网络。"
        )
        #expect(LocalSharingPresentation.localNetworkPermissionMessage == "请在系统设置中允许本地网络访问。")
    }

    @Test func localSharingOffersOnlyViewerInvitations() {
        #expect(LocalSharingPresentation.invitationRole == .viewer)

        let viewerInvitation = LocalSharingInvitation(
            role: .viewer,
            url: URL(string: "http://live-church-translation.local:8123/#invite=viewer")!
        )
        let operatorInvitation = LocalSharingInvitation(
            role: .operator,
            url: URL(string: "http://live-church-translation.local:8123/#invite=operator")!
        )

        #expect(LocalSharingPresentation.visibleInvitation(viewerInvitation) == viewerInvitation)
        #expect(LocalSharingPresentation.visibleInvitation(operatorInvitation) == nil)
    }
}
