import AppKit
import RemoteSharingFeatureAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

enum LocalSharingPresentation {
    static let subtitle = "听众需连接同一网络。"
    static let localNetworkPermissionMessage = "请在系统设置中允许本地网络访问。"
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
            Label(displayLanguage.interfaceText(title), systemImage: icon)
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
        let simplifiedText =
            switch state {
            case .off: "共享已关闭"
            case .starting: "正在启动共享"
            case .on: "共享已开启"
            case .localNetworkPermissionDenied: "未获得本地网络权限"
            case .failed: "共享失败"
            }
        return displayLanguage.interfaceText(simplifiedText)
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
        case .viewer: "听众"
        case .operator: "协助者 · 仅可停止"
        }
    }
}
