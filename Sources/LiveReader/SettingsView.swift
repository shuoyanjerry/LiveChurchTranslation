import AudioCaptureAPI
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LiveReaderViewModel

    var body: some View {
        Form {
            Section("Audio Input") {
                Picker("Microphone", selection: $viewModel.selectedInputID) {
                    Text("System Default").tag(AudioInputID?.none)
                    ForEach(viewModel.devices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
            }
            Section("Live Reader") {
                HStack {
                    Text("English text size")
                    Slider(value: $viewModel.settings.readerFontSize, in: 18...44, step: 1)
                    Text("\(Int(viewModel.settings.readerFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 48)
                }
                Toggle("Show recognized Chinese below English", isOn: $viewModel.settings.showSourceText)
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
                Button("Done") {
                    Task { await viewModel.saveSettings() }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 620, height: 430)
    }
}
