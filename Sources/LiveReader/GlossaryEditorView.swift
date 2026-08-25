import GlossaryAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

struct GlossaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage
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
                Text(displayLanguage.interfaceText("属灵术语表")).font(.title2.bold())
                Spacer()
                Button(displayLanguage.interfaceText("恢复默认")) {
                    restoreDefaults()
                }
                Button {
                    entries.append(GlossaryEntry(source: "", target: ""))
                } label: {
                    Label(displayLanguage.interfaceText("添加"), systemImage: "plus")
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
                    Text(displayLanguage.interfaceText("请检查词条后重试。"))
                        .font(.caption)
                        .foregroundStyle(ChurchTheme.danger)
                }
                Spacer()
                Button(displayLanguage.interfaceText("取消")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(displayLanguage.interfaceText("保存")) {
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
