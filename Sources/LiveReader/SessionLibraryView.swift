import PersistenceAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

struct SessionLibraryView: View {
    @ObservedObject var viewModel: SessionLibraryViewModel
    let onImport: (TranslationMode) -> Void
    let onRetranscribe: (StoredSessionSummary) -> Void
    let onCancelImport: () -> Void
    @State private var confirmsDeletion = false

    var body: some View {
        HStack(spacing: 0) {
            sessionList
                .frame(minWidth: 270, idealWidth: 310, maxWidth: 360)
            Divider().overlay(ChurchTheme.stone)
            SessionLibraryDetail(
                viewModel: viewModel,
                confirmsDeletion: $confirmsDeletion,
                onRetranscribe: onRetranscribe
            )
        }
        .background(ChurchTheme.background)
        .task { await viewModel.load() }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            )
        ) {
            Button("好") { viewModel.presentedError = nil }
        } message: {
            Text(viewModel.presentedError ?? "请重试。")
        }
        .confirmationDialog(
            "删除这场会议？",
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button("删除会议", role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(SessionLibraryPresentation.deletionMessage)
        }
    }

    private var sessionList: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("资料库")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text("\(viewModel.sessions.count) 个项目")
                        .font(.caption)
                        .foregroundStyle(ChurchTheme.muted)
                }
                Spacer()
                if viewModel.isImporting {
                    Button(action: onCancelImport) {
                        Label("正在听抄", systemImage: "stop.fill")
                            .foregroundStyle(ChurchTheme.danger)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("停止导入音频听抄")
                    .help("停止听抄")
                } else {
                    Menu {
                        Section("选择录音语言") {
                            ForEach(TranslationMode.allCases) { mode in
                                Button(SessionLibraryPresentation.importLanguageLabel(for: mode)) {
                                    onImport(mode)
                                }
                            }
                        }
                    } label: {
                        InlineMenuLabel(title: "导入并听抄", systemImage: "plus")
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel("导入音频并生成听抄稿")
                    .help(SessionLibraryPresentation.importHelp)
                }
            }
            .padding(20)

            TextField("搜索", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().overlay(ChurchTheme.stone)
            if viewModel.filteredSessions.isEmpty {
                ContentUnavailableView(
                    "尚无会议内容",
                    systemImage: "waveform",
                    description: Text("实时录音和导入生成的听抄稿会出现在这里。")
                )
            } else {
                List(viewModel.filteredSessions, selection: selectionBinding) { summary in
                    SessionLibraryRow(summary: summary)
                        .tag(summary.id)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(ChurchTheme.surface)
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedSessionID },
            set: { id in Task { await viewModel.select(id) } }
        )
    }
}

enum SessionLibraryPresentation {
    static let deletionMessage = "听抄稿和完整录音将从此 Mac 删除，且无法恢复。"
    static let importHelp = "选择录音语言，只生成听抄稿，不会翻译。"

    static func importLanguageLabel(for mode: TranslationMode) -> String {
        "\(mode.sourceDisplayName)录音"
    }
}
