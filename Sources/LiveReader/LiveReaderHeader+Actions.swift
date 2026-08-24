import SwiftUI
import UIDesignSystem

extension LiveReaderHeader {
    var optionsMenu: some View {
        Menu {
            Button("属灵术语表", systemImage: "character.book.closed") {
                showsGlossary = true
            }
            Button("阅读与翻译设置", systemImage: "slider.horizontal.3") {
                showsSettings = true
            }
        } label: {
            InlineMenuLabel(title: "更多", systemImage: "ellipsis")
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(ChurchTheme.ink)
        .accessibilityLabel("更多选项")
    }

    var sessionButton: some View {
        Button {
            Task { await viewModel.toggleSession() }
        } label: {
            Label(sessionButtonTitle, systemImage: sessionButtonIcon)
        }
        .buttonStyle(ChurchPrimaryButtonStyle())
        .disabled(viewModel.externalSessionControlLock && !viewModel.isRunning)
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityHint("开始或停止实时语音识别、翻译和录音")
    }
}

struct InlineMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .frame(width: 14)
            Text(title)
                .lineLimit(1)
        }
        .font(.callout.weight(.medium))
        .fixedSize(horizontal: true, vertical: false)
    }
}
