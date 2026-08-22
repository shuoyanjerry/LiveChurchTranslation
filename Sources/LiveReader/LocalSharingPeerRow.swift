import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

struct LocalSharingPeerRow: View {
    let peer: LocalSharingPeer
    let onIntent: LocalSharingIntentHandler

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle")
                .foregroundStyle(ChurchTheme.olive)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ChurchTheme.ink)
                Text(peer.role.displayName)
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
            }
            Spacer()
            Menu {
                Button("Revoke Access", role: .destructive) {
                    onIntent(.revoke(peerID: peer.id))
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Actions for \(peer.name)")
        }
        .accessibilityElement(children: .contain)
    }
}
