import GlossaryAPI
import SwiftUI
import UIDesignSystem

struct GlossaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [GlossaryEntry]
    @State private var isWorking = false
    @State private var operationFailed = false
    let onSave: @MainActor ([GlossaryEntry]) async -> Bool
    let onRestore: @MainActor () async -> [GlossaryEntry]?

    init(
        entries: [GlossaryEntry],
        onSave: @escaping @MainActor ([GlossaryEntry]) async -> Bool,
        onRestore: @escaping @MainActor () async -> [GlossaryEntry]?
    ) {
        _entries = State(initialValue: entries)
        self.onSave = onSave
        self.onRestore = onRestore
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Theological Glossary").font(.title2.bold())
                    Text("Longer phrases take priority. ASR aliases repair known mishearings.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restore Defaults") {
                    restoreDefaults()
                }
                Button {
                    entries.append(GlossaryEntry(source: "", target: ""))
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding()
            Divider()
            List {
                ForEach($entries) { $entry in
                    GlossaryEntryEditorRow(entry: $entry) {
                        entries.removeAll { $0.id == entry.id }
                    }
                }
            }
            Divider()
            HStack {
                if operationFailed {
                    Text("Could not save. Review the highlighted issue and try again.")
                        .font(.caption)
                        .foregroundStyle(ChurchTheme.danger)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isWorking)
                if isWorking { ProgressView().controlSize(.small) }
            }
            .padding()
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private func save() {
        Task { @MainActor in
            isWorking = true
            operationFailed = false
            let succeeded = await onSave(entries)
            isWorking = false
            if succeeded { dismiss() } else { operationFailed = true }
        }
    }

    private func restoreDefaults() {
        Task { @MainActor in
            isWorking = true
            operationFailed = false
            if let restored = await onRestore() {
                entries = restored
            } else {
                operationFailed = true
            }
            isWorking = false
        }
    }
}
