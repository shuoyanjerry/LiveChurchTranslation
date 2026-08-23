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
                Text("所选语言方向同时用于实时语音和之后导入的音频。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        "请先结束当前实时会议或音频导入，再更改语言方向或麦克风。"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Section("实时阅读") {
                HStack {
                    Text("译文大小")
                    Slider(value: $draftSettings.readerFontSize, in: 18...44, step: 1)
                    Text("\(Int(draftSettings.readerFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48)
                }
                Toggle("在译文下方显示识别原文", isOn: $draftSettings.showSourceText)
            }
            Section("本机模型") {
                LabeledContent("中英语音识别", value: "Qwen3-ASR 0.6B · ONNX INT8")
                LabeledContent("中英双向翻译", value: "Hy-MT2 1.8B · Metal Q4")
                Text("约 2.1 GB 模型已随应用安装；首次启动只需校验并载入，断网也可使用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("经文与属灵术语") {
                LabeledContent(
                    "英语经文基线",
                    value: ScriptureSettingsPresentation.englishBaseline
                )
                LabeledContent(
                    "中文经文基线",
                    value: ScriptureSettingsPresentation.simplifiedChineseBaseline
                )
                Text(ScriptureSettingsPresentation.notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("隐私") {
                Text("会议录音、听抄稿和翻译仅保存在此 Mac。")
                    .foregroundStyle(.secondary)
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
