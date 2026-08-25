import Foundation
import GlossaryAPI
import SettingsAPI
import SwiftUI

struct GlossaryEntryEditorRow: View {
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage
    @Binding private var entry: GlossaryEntry
    @State private var aliasesText: String
    private let onDelete: () -> Void

    init(entry: Binding<GlossaryEntry>, onDelete: @escaping () -> Void) {
        _entry = entry
        _aliasesText = State(
            initialValue: entry.wrappedValue.recognitionAliases.joined(separator: "，")
        )
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Toggle("", isOn: $entry.isEnabled).labelsHidden()
                TextField(
                    displayLanguage.interfaceText("中文词汇或经文短语"),
                    text: $entry.source
                )
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                TextField(
                    displayLanguage.interfaceText("忠实、合乎属灵语境的英语译法"),
                    text: $entry.target
                )
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Text(displayLanguage.interfaceText("常见说法"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(displayLanguage.interfaceText("用逗号分隔"), text: $aliasesText)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aliasesText) { _, value in
                        entry.recognitionAliases = Self.parseAliases(value)
                    }
            }
            .padding(.leading, 30)
        }
        .padding(.vertical, 5)
    }

    private static func parseAliases(_ text: String) -> [String] {
        var seen = Set<String>()
        return
            text
            .split(whereSeparator: { ",，;；\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
