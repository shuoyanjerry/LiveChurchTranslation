import SettingsAPI
import SwiftUI
import UIDesignSystem

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(displayLanguage.interfaceText("隐私与数据"))
                    .font(.title2.weight(.semibold))
                Spacer()
                Button(displayLanguage.interfaceText("完成")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            Divider().overlay(ChurchTheme.stone)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(
                        "本地处理",
                        "现场语音识别与翻译只在这台 Mac 上处理；导入媒体只生成听抄稿，不翻译。"
                    )
                    section(
                        "本地保存",
                        "资料库保存录音与语音识别原文，不保存译文；可随时删除。"
                    )
                    section(
                        "听众共享",
                        "只在可信网络中开启；已配对设备可以查看字幕。"
                    )
                    section(
                        "录音",
                        "开始前请告知现场人员。"
                    )
                    Text(displayLanguage.interfaceText("隐私联系：jerryyanshuo@outlook.com"))
                        .font(.caption)
                        .foregroundStyle(ChurchTheme.muted)
                }
                .padding(28)
            }
        }
        .frame(width: 600, height: 520)
        .background(ChurchTheme.background)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(displayLanguage.interfaceText(title)).font(.headline)
            Text(displayLanguage.interfaceText(text))
                .font(.body)
                .foregroundStyle(ChurchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
