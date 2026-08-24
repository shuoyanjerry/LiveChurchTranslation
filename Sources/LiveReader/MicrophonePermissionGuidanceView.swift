import SwiftUI
import UIDesignSystem

struct MicrophonePermissionGuidanceView: View {
    @ObservedObject var coordinator: MicrophonePermissionCoordinator

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
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
            .padding(.bottom, 28)
            Divider().overlay(ChurchTheme.stone)
            HStack(spacing: 12) {
                Button("稍后") { coordinator.deferGuidance() }
                    .buttonStyle(ChurchSecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                primaryButton
            }
            .padding(24)
        }
        .frame(width: 420)
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
        case .notDetermined: "允许麦克风"
        case .denied: "需要麦克风权限"
        case .restricted: "麦克风访问受限"
        case nil: ""
        }
    }

    private var message: String {
        switch coordinator.guidance {
        case .notDetermined:
            "实时翻译需要使用麦克风。"
        case .denied:
            "请在系统设置中允许 Live Church Translation 使用麦克风。"
        case .restricted:
            "此 Mac 不允许访问麦克风。"
        case nil: ""
        }
    }

    private var icon: String {
        coordinator.guidance == .notDetermined ? "waveform.and.mic" : "mic.slash"
    }
}
