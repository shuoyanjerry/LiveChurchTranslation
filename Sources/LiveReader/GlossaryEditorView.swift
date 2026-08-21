import GlossaryAPI
import SwiftUI
import UIDesignSystem

struct GlossaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [GlossaryEntry]
    let onSave: ([GlossaryEntry]) -> Void
    let onRestore: () -> Void

    init(
        entries: [GlossaryEntry],
        onSave: @escaping ([GlossaryEntry]) -> Void,
        onRestore: @escaping () -> Void
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
                    onRestore()
                    dismiss()
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
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(entries)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}
