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
            Section("Translation") {
                Picker("Mode", selection: $draftSettings.translationMode) {
                    ForEach(TranslationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.sessionControlsLocked)
                Text("The selected language pair applies to live speech and new audio imports.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Audio Input") {
                Picker("Microphone", selection: $draftInputID) {
                    Text("System Default").tag(AudioInputID?.none)
                    ForEach(viewModel.devices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                .disabled(viewModel.sessionControlsLocked)
                if viewModel.sessionControlsLocked {
                    Text(
                        "Finish the current live session or audio import "
                            + "before changing its mode or microphone."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Section("Live Reader") {
                HStack {
                    Text("Translation text size")
                    Slider(value: $draftSettings.readerFontSize, in: 18...44, step: 1)
                    Text("\(Int(draftSettings.readerFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48)
                }
                Toggle("Show recognized source below translation", isOn: $draftSettings.showSourceText)
            }
            Section("On-device Models") {
                LabeledContent("Multilingual ASR", value: "Qwen3-ASR 0.6B · ONNX INT8")
                LabeledContent("Chinese ↔ English", value: "Hy-MT2 1.8B · Metal Q4")
                Text("About 2.1 GB downloads once; inference then stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Privacy") {
                Text("Meeting audio, transcripts, and translations stay on this Mac.")
                    .foregroundStyle(.secondary)
                Button("Privacy & Data…") { showsPrivacy = true }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
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
