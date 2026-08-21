import Foundation
import GlossaryAPI
import SwiftUI

struct GlossaryEntryEditorRow: View {
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
                TextField("中文词汇或经文短语", text: $entry.source)
                Image(systemName: "arrow.right").foregroundStyle(.secondary)
                TextField("Faithful English rendering", text: $entry.target)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 8) {
                Text("ASR aliases")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("常见误听；用逗号分隔，例如：休恩", text: $aliasesText)
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
