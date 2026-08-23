import SwiftUI
import UIDesignSystem

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("隐私与数据")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            Divider().overlay(ChurchTheme.stone)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section(
                        "本地处理",
                        "麦克风音频、导入音频、听抄稿和翻译都在这台 Mac 上处理。"
                            + "会议内容不会发送给开发者或第三方 AI 服务。"
                    )
                    section(
                        "本地保存",
                        "完整录音、听抄稿、翻译和时间戳保存在 App Sandbox 中，"
                            + "直到你在资料库中删除该会议。"
                    )
                    section(
                        "听众共享",
                        "本地共享默认关闭。启用后，只有明确配对的设备会收到字幕；"
                            + "音频文件不会发送给听众设备。请仅在可信局域网中使用。"
                    )
                    section(
                        "录音责任",
                        "开始前请告知现场参与者，并取得当地法律要求的同意。"
                            + "录音期间应用会持续显示红色状态和计时。"
                    )
                    Text("隐私联系：jerryyanshuo@outlook.com")
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
            Text(title).font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(ChurchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
