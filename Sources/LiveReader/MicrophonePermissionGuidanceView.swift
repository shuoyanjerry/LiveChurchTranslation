import SwiftUI
import UIDesignSystem

struct MicrophonePermissionGuidanceView: View {
    @ObservedObject var coordinator: MicrophonePermissionCoordinator

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(ChurchTheme.olive)
                    .frame(width: 72, height: 72)
                    .background(ChurchTheme.surfaceWarm, in: Circle())
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(ChurchTheme.ink)
                    Text(message)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ChurchTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 38)
            .padding(.top, 34)
            .padding(.bottom, 26)
            Divider().overlay(ChurchTheme.stone)
            VStack(spacing: 14) {
                Text("你仍可导入音频或浏览资料库；设备端模型会继续在后台自动准备。")
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button("稍后") { coordinator.deferGuidance() }
                        .buttonStyle(ChurchSecondaryButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    primaryButton
                }
            }
            .padding(24)
        }
        .frame(width: 470)
        .background(ChurchTheme.background)
    }

    @ViewBuilder private var primaryButton: some View {
        switch coordinator.guidance {
        case .notDetermined:
            Button {
                Task { await coordinator.requestAccess() }
            } label: {
                if coordinator.isRequesting {
                    ProgressView().controlSize(.small)
                } else {
                    Label("允许麦克风", systemImage: "mic.fill")
                }
            }
            .buttonStyle(ChurchPrimaryButtonStyle())
            .disabled(coordinator.isRequesting)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel(coordinator.isRequesting ? "正在请求麦克风权限" : "允许麦克风")
        case .denied, .restricted:
            Button {
                coordinator.openSystemSettings()
            } label: {
                Label("打开系统设置", systemImage: "gear")
            }
            .buttonStyle(ChurchPrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        case nil:
            EmptyView()
        }
    }

    private var title: String {
        switch coordinator.guidance {
        case .notDetermined: "启用实时语音"
        case .denied: "需要麦克风权限"
        case .restricted: "麦克风访问受限"
        case nil: ""
        }
    }

    private var message: String {
        switch coordinator.guidance {
        case .notDetermined:
            "实时听抄与翻译需要使用麦克风。音频只在这台 Mac 上处理；"
                + "仅在你点按“允许麦克风”后，应用才会显示 macOS 授权窗口。"
        case .denied:
            "麦克风权限当前已关闭。请在“系统设置 > 隐私与安全性 > 麦克风”中"
                + "允许“教会实时翻译”使用麦克风。"
        case .restricted:
            "此 Mac 的管理或家长控制策略限制了麦克风访问。你可以打开系统设置检查限制。"
        case nil: ""
        }
    }

    private var icon: String {
        coordinator.guidance == .notDetermined ? "waveform.and.mic" : "mic.slash"
    }
}
