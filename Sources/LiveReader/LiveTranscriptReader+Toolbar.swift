import SettingsAPI
import SwiftUI
import UIDesignSystem

extension LiveTranscriptReader {
    var readerToolbar: some View {
        HStack(spacing: 18) {
            Text(verbatim: modeCaption)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(ChurchTheme.olive)
            Spacer()
            Picker(
                "翻译方向",
                selection: Binding(
                    get: { viewModel.settings.translationMode },
                    set: { mode in Task { await viewModel.selectTranslationMode(mode) } }
                )
            ) {
                ForEach(TranslationMode.allCases) { mode in
                    Text(
                        verbatim: displayLanguage.interfaceText(mode.compactDisplayName)
                    )
                    .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .disabled(viewModel.sessionControlsLocked)
            sourceTextButton
            timestampButton
        }
    }

    private var sourceTextButton: some View {
        Button {
            toggleReaderSetting(\.showSourceText)
        } label: {
            readerSettingLabel("识别原文", isOn: viewModel.settings.showSourceText)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ChurchTheme.olive)
        .accessibilityValue(
            Text(
                verbatim: displayLanguage.interfaceText(
                    viewModel.settings.showSourceText ? "已显示" : "已隐藏"
                )
            )
        )
    }

    private var timestampButton: some View {
        Button {
            toggleReaderSetting(\.showTimestamps)
        } label: {
            readerSettingLabel("时间戳", isOn: viewModel.settings.showTimestamps)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ChurchTheme.olive)
        .accessibilityValue(
            Text(
                verbatim: displayLanguage.interfaceText(
                    viewModel.settings.showTimestamps ? "已显示" : "已隐藏"
                )
            )
        )
        .help("显示或隐藏每段翻译的时间")
    }

    private func readerSettingLabel(_ title: String, isOn: Bool) -> some View {
        HStack(spacing: 7) {
            Text(verbatim: displayLanguage.interfaceText(title))
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
        }
        .frame(minHeight: 44)
    }

    private func toggleReaderSetting(_ keyPath: WritableKeyPath<AppSettings, Bool>) {
        let previousSettings = viewModel.settings
        viewModel.settings[keyPath: keyPath].toggle()
        Task {
            if !(await viewModel.saveSettings()) {
                viewModel.settings = previousSettings
            }
        }
    }

    private var modeCaption: String {
        let caption =
            switch viewModel.settings.translationMode {
            case .mandarinToEnglish: "普通话信息 · 英语翻译"
            case .englishToSimplifiedChinese: "英语信息 · 简体中文翻译"
            }
        return displayLanguage.interfaceText(caption)
    }

    func scrollToLive(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("live-edge", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("live-edge", anchor: .bottom)
            }
        }
    }

    var jumpLabel: String {
        let label =
            if liveFollow.unseenEntryCount > 0 {
                "回到最新 · \(liveFollow.unseenEntryCount) 条新内容"
            } else {
                "回到最新"
            }
        return displayLanguage.interfaceText(label)
    }
}
