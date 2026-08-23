import AppKit
import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

enum LocalSharingPresentation {
    static let subtitle = "Nearby devices can read the live transcript and translation."
    static let transportWarning = "Trusted local network only · Traffic is not encrypted"
    static let localNetworkPermissionMessage =
        "本地网络访问已被 macOS 阻止。请在“系统设置 > 隐私与安全性 > 本地网络”中允许本应用。"
    static let invitationRole = LocalSharingInvitationRole.viewer

    static func visibleInvitation(
        _ invitation: LocalSharingInvitation?
    ) -> LocalSharingInvitation? {
        guard invitation?.role == .viewer else { return nil }
        return invitation
    }
}

extension LocalSharingPopover {
    func actionButton(
        _ title: String,
        icon: String,
        intent: LocalSharingIntent
    ) -> some View {
        Button {
            onIntent(intent)
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(ChurchSecondaryButtonStyle())
    }

    var statusColor: Color {
        switch state {
        case .off: ChurchTheme.stone
        case .starting: ChurchTheme.warning
        case .on: ChurchTheme.live
        case .localNetworkPermissionDenied: ChurchTheme.warning
        case .failed: ChurchTheme.danger
        }
    }

    var statusLabel: String {
        switch state {
        case .off: "Sharing off"
        case .starting: "Sharing starting"
        case .on: "Sharing on"
        case .localNetworkPermissionDenied: "Local network permission denied"
        case .failed: "Sharing failed"
        }
    }

    func openLocalNetworkSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork"
            )
        else { return }
        _ = NSWorkspace.shared.open(url)
    }
}

extension LocalSharingPeerRole {
    var displayName: String {
        switch self {
        case .viewer: "Viewer"
        case .operator: "Operator · Stop only"
        }
    }
}
