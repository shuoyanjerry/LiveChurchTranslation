import AudioCaptureAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LiveReaderViewModel
    @State private var draftSettings: AppSettings
    @State private var draftInputID: AudioInputID?
    @State private var showsPrivacy = false

    init(viewModel: LiveReaderViewModel) {
        self.viewModel = viewModel
        _draftSettings = State(initialValue: viewModel.settings)
        _draftInputID = State(initialValue: viewModel.selectedInputID)
    }

    var body: some View {
        Form {
            Section("翻译") {
                Picker("语言方向", selection: $draftSettings.translationMode) {
                    ForEach(TranslationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.sessionControlsLocked)
            }
            Section("音频输入") {
                Picker("麦克风", selection: $draftInputID) {
                    Text("系统默认麦克风").tag(AudioInputID?.none)
                    ForEach(viewModel.devices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                .disabled(viewModel.sessionControlsLocked)
                if viewModel.sessionControlsLocked {
                    Text(
                        viewModel.isRunning
                            ? "实时翻译中，暂时不能更改。"
                            : "正在处理音频，暂时不能更改。"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Section("实时阅读") {
                HStack {
                    Text("译文大小")
                    Slider(
                        value: $draftSettings.readerFontSize,
                        in: AppSettings.readerFontSizeRange,
                        step: 1
                    )
                    Text("\(Int(draftSettings.readerFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48)
                }
                Toggle("在译文下方显示识别原文", isOn: $draftSettings.showSourceText)
            }
            Section("隐私") {
                LabeledContent("数据位置", value: "仅此 Mac")
                Button("隐私与数据…") { showsPrivacy = true }
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    Task {
                        let previousSettings = viewModel.settings
                        let previousInputID = viewModel.selectedInputID
                        var settingsToSave = draftSettings
                        var inputToSave = draftInputID
                        if viewModel.sessionControlsLocked {
                            settingsToSave.translationMode = previousSettings.translationMode
                            inputToSave = previousInputID
                        }
                        viewModel.settings = settingsToSave
                        viewModel.selectedInputID = inputToSave
                        if await viewModel.saveSettings() {
                            dismiss()
                        } else {
                            viewModel.settings = previousSettings
                            viewModel.selectedInputID = previousInputID
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(ChurchPrimaryButtonStyle())
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 640, height: 580)
        .sheet(isPresented: $showsPrivacy) { PrivacyView() }
    }
}
