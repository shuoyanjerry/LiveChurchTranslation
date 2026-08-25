import PersistenceAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

struct SessionLibraryView: View {
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage
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
            displayLanguage.interfaceText("操作未完成"),
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            )
        ) {
            Button(displayLanguage.interfaceText("好")) { viewModel.presentedError = nil }
        } message: {
            Text(displayLanguage.interfaceText(viewModel.presentedError ?? "请重试。"))
        }
        .confirmationDialog(
            displayLanguage.interfaceText("删除这场会议？"),
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button(displayLanguage.interfaceText("删除会议"), role: .destructive) {
                Task { await viewModel.deleteSelected() }
            }
            Button(displayLanguage.interfaceText("取消"), role: .cancel) {}
        } message: {
            Text(SessionLibraryPresentation.deletionMessage(displayLanguage: displayLanguage))
        }
    }

    private var sessionList: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayLanguage.interfaceText("资料库"))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                    Text(displayLanguage.interfaceText("\(viewModel.sessions.count) 个项目"))
                        .font(.caption)
                        .foregroundStyle(ChurchTheme.muted)
                }
                Spacer()
                if viewModel.isImporting {
                    Button(action: onCancelImport) {
                        Label(displayLanguage.interfaceText("正在听抄"), systemImage: "stop.fill")
                            .foregroundStyle(ChurchTheme.danger)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(displayLanguage.interfaceText("停止导入媒体听抄"))
                    .help(displayLanguage.interfaceText("停止听抄"))
                } else {
                    Menu {
                        Section(displayLanguage.interfaceText("选择内容语言")) {
                            ForEach(TranslationMode.allCases) { mode in
                                Button(
                                    SessionLibraryPresentation.importLanguageLabel(
                                        for: mode,
                                        displayLanguage: displayLanguage
                                    )
                                ) {
                                    onImport(mode)
                                }
                            }
                        }
                    } label: {
                        InlineMenuLabel(
                            title: displayLanguage.interfaceText("导入并听抄"),
                            systemImage: "plus"
                        )
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.borderlessButton)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityLabel(
                        displayLanguage.interfaceText("导入音频或视频并生成听抄稿")
                    )
                    .help(SessionLibraryPresentation.importHelp(displayLanguage: displayLanguage))
                }
            }
            .padding(20)

            TextField(displayLanguage.interfaceText("搜索"), text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().overlay(ChurchTheme.stone)
            if viewModel.filteredSessions.isEmpty {
                ContentUnavailableView(
                    displayLanguage.interfaceText("尚无会议内容"),
                    systemImage: "waveform",
                    description: Text(
                        displayLanguage.interfaceText("实时录音和导入生成的听抄稿会出现在这里。")
                    )
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
}

extension SessionLibraryView {
    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedSessionID },
            set: { id in Task { await viewModel.select(id) } }
        )
    }
}

enum SessionLibraryPresentation {
    static let deletionMessage = "听抄稿和完整录音将从此 Mac 删除，且无法恢复。"
    static let importHelp = "选择内容语言；支持常见音频和含音轨视频，只生成听抄稿，不会翻译。"

    static func deletionMessage(displayLanguage: DisplayLanguage) -> String {
        displayLanguage.interfaceText(deletionMessage)
    }

    static func importHelp(displayLanguage: DisplayLanguage) -> String {
        displayLanguage.interfaceText(importHelp)
    }

    static func importLanguageLabel(for mode: TranslationMode) -> String {
        "\(mode.sourceDisplayName)内容"
    }

    static func importLanguageLabel(
        for mode: TranslationMode,
        displayLanguage: DisplayLanguage
    ) -> String {
        displayLanguage.interfaceText(importLanguageLabel(for: mode))
    }
}
