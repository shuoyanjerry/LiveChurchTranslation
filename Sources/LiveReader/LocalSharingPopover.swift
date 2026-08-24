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
            }
            Spacer()
            statusIndicator
                .accessibilityLabel(statusLabel)
        }
    }

    @ViewBuilder private var statusIndicator: some View {
        if case .starting = state {
            ProgressView()
                .controlSize(.mini)
        } else {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
        }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .off:
            offContent
        case .starting:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("正在开启共享…")
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
        case .on(_, let connectionCount, let invitation, let peers):
            activeContent(connectionCount, invitation, peers)
        case .failed:
            Text("共享未开启，请重试。")
                .foregroundStyle(ChurchTheme.danger)
            actionButton("重试", icon: "arrow.clockwise", intent: .toggle)
        }
    }

    private var offContent: some View {
        VStack(alignment: .leading) {
            actionButton("开启听众共享", icon: "antenna.radiowaves.left.and.right", intent: .toggle)
        }
    }

    private func activeContent(
        _ connectionCount: Int,
        _ invitation: LocalSharingInvitation?,
        _ peers: [LocalSharingPeer]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(connectionCount == 0 ? "等待听众连接" : "\(connectionCount) 台设备正在查看")
                .font(.callout.weight(.medium))
            if let invitation = LocalSharingPresentation.visibleInvitation(invitation) {
                invitationView(invitation)
            } else {
                actionButton(
                    "显示听众二维码",
                    icon: "qrcode",
                    intent: .createInvitation(role: LocalSharingPresentation.invitationRole)
                )
            }
            if !peers.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(peers) { peer in
                            Divider()
                            LocalSharingPeerRow(peer: peer, onIntent: onIntent)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            Button("停止共享", role: .destructive) { onIntent(.toggle) }
        }
    }

}
