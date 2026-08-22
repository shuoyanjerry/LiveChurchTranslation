import AudioCaptureAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LiveReaderViewModel
    @State private var draftSettings: AppSettings
    @State private var draftInputID: AudioInputID?

    init(viewModel: LiveReaderViewModel) {
        self.viewModel = viewModel
        _draftSettings = State(initialValue: viewModel.settings)
        _draftInputID = State(initialValue: viewModel.selectedInputID)
    }

    var body: some View {
        Form {
            Section("Audio Input") {
                Picker("Microphone", selection: $draftInputID) {
                    Text("System Default").tag(AudioInputID?.none)
                    ForEach(viewModel.devices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
            }
            Section("Live Reader") {
                HStack {
                    Text("English text size")
                    Slider(value: $draftSettings.readerFontSize, in: 18...44, step: 1)
                    Text("\(Int(draftSettings.readerFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48)
                }
                Toggle("Show recognized Chinese below English", isOn: $draftSettings.showSourceText)
            }
            Section("On-device Models") {
                LabeledContent("Mandarin ASR", value: "Qwen3-ASR 0.6B · ONNX INT8")
                LabeledContent("Translation", value: "Hy-MT2 1.8B · Metal Q4")
                Text("About 2.1 GB downloads once; inference then stays on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task {
                        let previousSettings = viewModel.settings
                        let previousInputID = viewModel.selectedInputID
                        viewModel.settings = draftSettings
                        viewModel.selectedInputID = draftInputID
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
        .frame(width: 640, height: 480)
    }
}
