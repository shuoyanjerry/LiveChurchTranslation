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
                Button("撤销访问", role: .destructive) {
                    onIntent(.revoke(peerID: peer.id))
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("\(peer.name) 的操作")
        }
        .accessibilityElement(children: .contain)
    }
}
