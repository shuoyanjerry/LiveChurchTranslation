import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

enum LocalSharingPresentation {
    static let subtitle = "Nearby devices can read the live transcript and translation."
    static let transportWarning = "Trusted local network only · Traffic is not encrypted"
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
        case .failed: ChurchTheme.danger
        }
    }

    var statusLabel: String {
        switch state {
        case .off: "Sharing off"
        case .starting: "Sharing starting"
        case .on: "Sharing on"
        case .failed: "Sharing failed"
        }
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
