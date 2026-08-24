import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

extension LocalSharingPopover {
    func invitationView(_ invitation: LocalSharingInvitation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("听众二维码")
                .font(.caption.weight(.semibold))
            if let code = InvitationQRCode.image(for: invitation.url) {
                VStack(spacing: 7) {
                    Image(nsImage: code)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 156, height: 156)
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("听众邀请二维码")
                    Text("停止共享前可供多人扫码")
                        .font(.caption)
                        .foregroundStyle(ChurchTheme.muted)
                }
                .frame(maxWidth: .infinity)
            }
            ShareLink(item: invitation.url) {
                Label("分享链接", systemImage: "square.and.arrow.up")
            }
        }
        .padding(12)
        .background(ChurchTheme.surfaceWarm, in: RoundedRectangle(cornerRadius: 8))
    }

}
