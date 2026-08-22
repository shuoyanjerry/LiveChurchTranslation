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
                Text("Local Reader")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ChurchTheme.ink)
                Text("Nearby devices can read the English transcript.")
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
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
                Text("Starting local sharing…")
            }
        case .on(let endpoint, let connectionCount, let invitation, let peers):
            activeContent(endpoint, connectionCount, invitation, peers)
        case .failed(let message):
            Text(message).foregroundStyle(ChurchTheme.danger)
            actionButton("Try Again", icon: "arrow.clockwise", intent: .toggle)
        }
    }

    private var offContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sharing is off. Turn it on only when people in the room need a reader.")
                .font(.callout)
                .foregroundStyle(ChurchTheme.muted)
            actionButton("Turn On Local Sharing", icon: "antenna.radiowaves.left.and.right", intent: .toggle)
        }
    }

    private func activeContent(
        _ endpoint: URL,
        _ connectionCount: Int,
        _ invitation: LocalSharingInvitation?,
        _ peers: [LocalSharingPeer]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(connectionCount) connected · \(peers.count) paired")
                .font(.callout.weight(.medium))
            Text(endpoint.absoluteString)
                .font(.caption.monospaced())
                .foregroundStyle(ChurchTheme.muted)
                .textSelection(.enabled)
            if let invitation {
                invitationView(invitation)
            }
            actionButton(
                "Invite a Viewer",
                icon: "person.badge.plus",
                intent: .createInvitation(role: .viewer)
            )
            actionButton(
                "Invite an Operator (Start/Stop)",
                icon: "person.badge.key",
                intent: .createInvitation(role: .operator)
            )
            ForEach(peers) { peer in
                Divider()
                LocalSharingPeerRow(peer: peer, onIntent: onIntent)
            }
            Button("Stop Sharing", role: .destructive) { onIntent(.toggle) }
        }
    }

    private func invitationView(_ invitation: LocalSharingInvitation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(invitation.role.displayName) invitation")
                .font(.caption.weight(.semibold))
            VStack(alignment: .leading, spacing: 3) {
                Text(invitation.url.absoluteString)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)
                Text("Expires in \(Text(invitation.expiresAt, style: .timer))")
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
            }
            ShareLink(item: invitation.url) {
                Label("Share Invite Link", systemImage: "square.and.arrow.up")
            }
        }
        .padding(12)
        .background(ChurchTheme.surfaceWarm, in: RoundedRectangle(cornerRadius: 8))
    }
}
