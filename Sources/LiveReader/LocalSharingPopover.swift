import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

struct LocalSharingPopover: View {
    let state: LocalSharingViewState
    let onIntent: LocalSharingIntentHandler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            title
            Divider()
            content
        }
        .padding(20)
        .frame(width: 340)
        .background(ChurchTheme.surface)
    }

    private var title: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("听众共享")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ChurchTheme.ink)
                Text(LocalSharingPresentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
                Label(LocalSharingPresentation.transportWarning, systemImage: "lock.slash")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ChurchTheme.warning)
            }
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .accessibilityLabel(statusLabel)
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .off:
            offContent
        case .starting:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("正在启动局域网共享…")
            }
        case .localNetworkPermissionDenied:
            Text(LocalSharingPresentation.localNetworkPermissionMessage)
                .foregroundStyle(ChurchTheme.muted)
            Button {
                openLocalNetworkSettings()
            } label: {
                Label("打开系统设置", systemImage: "gear")
            }
            .buttonStyle(ChurchPrimaryButtonStyle())
            actionButton("重试", icon: "arrow.clockwise", intent: .toggle)
        case .on(let endpoint, let connectionCount, let invitation, let peers):
            activeContent(endpoint, connectionCount, invitation, peers)
        case .failed(let message):
            Text(message).foregroundStyle(ChurchTheme.danger)
            actionButton("重试", icon: "arrow.clockwise", intent: .toggle)
        }
    }

    private var offContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("共享目前已关闭。仅在现场听众需要查看时开启。")
                .font(.callout)
                .foregroundStyle(ChurchTheme.muted)
            actionButton("开启局域网共享", icon: "antenna.radiowaves.left.and.right", intent: .toggle)
        }
    }

    private func activeContent(
        _ endpoint: URL,
        _ connectionCount: Int,
        _ invitation: LocalSharingInvitation?,
        _ peers: [LocalSharingPeer]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(connectionCount) 台已连接 · \(peers.count) 台已配对")
                .font(.callout.weight(.medium))
            Text(endpoint.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(ChurchTheme.muted)
                .textSelection(.enabled)
            if let invitation = LocalSharingPresentation.visibleInvitation(invitation) {
                invitationView(invitation)
            }
            actionButton(
                "邀请听众",
                icon: "person.badge.plus",
                intent: .createInvitation(role: LocalSharingPresentation.invitationRole)
            )
            ForEach(peers) { peer in
                Divider()
                LocalSharingPeerRow(peer: peer, onIntent: onIntent)
            }
            Button("停止共享", role: .destructive) { onIntent(.toggle) }
        }
    }

    private func invitationView(_ invitation: LocalSharingInvitation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(invitation.role.displayName)邀请")
                .font(.caption.weight(.semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text(invitation.url.absoluteString)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text("链接将在 \(Text(invitation.expiresAt, style: .timer)) 后失效")
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
            }
            ShareLink(item: invitation.url) {
                Label("分享邀请链接", systemImage: "square.and.arrow.up")
            }
        }
        .padding(12)
        .background(ChurchTheme.surfaceWarm, in: RoundedRectangle(cornerRadius: 8))
    }
}
