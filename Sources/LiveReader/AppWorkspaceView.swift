import AudioImportAPI
import Foundation
import PersistenceAPI
import RemoteSharingFeatureAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem
import UniformTypeIdentifiers

public struct AppWorkspaceView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var liveViewModel: LiveReaderViewModel
    @ObservedObject private var libraryViewModel: SessionLibraryViewModel
    @ObservedObject private var permissionCoordinator: MicrophonePermissionCoordinator
    @State private var selection = WorkspaceSection.live
    @State private var showsAudioImporter = false
    @State private var pendingImportMode: TranslationMode?
    private let sharingFeature: any LocalSharingFeature
    private let audioImporter: any AudioImporting

    public init(
        liveViewModel: LiveReaderViewModel,
        libraryViewModel: SessionLibraryViewModel,
        permissionCoordinator: MicrophonePermissionCoordinator,
        sharingFeature: any LocalSharingFeature,
        audioImporter: any AudioImporting
    ) {
        self.liveViewModel = liveViewModel
        self.libraryViewModel = libraryViewModel
        self.permissionCoordinator = permissionCoordinator
        self.sharingFeature = sharingFeature
        self.audioImporter = audioImporter
    }

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                brand
                List(WorkspaceSection.allCases, selection: $selection) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
            .background(ChurchTheme.surfaceWarm)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            switch selection {
            case .live:
                LiveReaderView(
                    viewModel: liveViewModel,
                    sharingFeature: sharingFeature
                )
            case .library:
                SessionLibraryView(
                    viewModel: libraryViewModel,
                    onImport: beginAudioImport,
                    onRetranscribe: beginRetranscription,
                    onCancelImport: { Task { await audioImporter.cancelImport() } }
                )
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task { await permissionCoordinator.load() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await permissionCoordinator.refresh() }
        }
        .sheet(isPresented: permissionPresentation) {
            MicrophonePermissionGuidanceView(coordinator: permissionCoordinator)
                .interactiveDismissDisabled(permissionCoordinator.isRequesting)
        }
        .onChange(of: libraryViewModel.isImporting, initial: true) { _, isImporting in
            liveViewModel.setExternalSessionControlLock(isImporting)
        }
        .fileImporter(
            isPresented: $showsAudioImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard
                case .success(let urls) = result,
                let url = urls.first,
                let mode = pendingImportMode
            else {
                pendingImportMode = nil
                if case .failure(let error) = result, !isUserCancellation(error) {
                    libraryViewModel.presentedError = "无法打开该音频文件。"
                }
                return
            }
            pendingImportMode = nil
            selection = .library
            liveViewModel.setExternalSessionControlLock(true)
            Task {
                await libraryViewModel.importAudio(
                    from: url,
                    mode: mode,
                    using: audioImporter,
                    liveSessionIsRunning: liveViewModel.isRunning
                )
                liveViewModel.setExternalSessionControlLock(false)
            }
        }
    }
}

extension AppWorkspaceView {
    fileprivate func beginAudioImport(mode: TranslationMode) {
        guard !liveViewModel.isRunning else {
            libraryViewModel.presentedError = "请先停止实时翻译。"
            return
        }
        pendingImportMode = mode
        showsAudioImporter = true
    }

    fileprivate func beginRetranscription(_ summary: StoredSessionSummary) {
        guard !liveViewModel.isRunning else {
            libraryViewModel.presentedError = "请先停止实时翻译。"
            return
        }
        guard !libraryViewModel.isImporting else { return }
        Task {
            await libraryViewModel.retranscribeRetainedRecording(
                for: summary,
                using: audioImporter,
                liveSessionIsRunning: liveViewModel.isRunning
            )
        }
    }

    fileprivate func isUserCancellation(_ error: any Error) -> Bool {
        let cocoaError = error as NSError
        return cocoaError.domain == NSCocoaErrorDomain
            && cocoaError.code == NSUserCancelledError
    }

    fileprivate var permissionPresentation: Binding<Bool> {
        Binding(
            get: { permissionCoordinator.isPresented },
            set: { isPresented in
                if !isPresented { permissionCoordinator.deferGuidance() }
            }
        )
    }

    fileprivate var brand: some View {
        HStack(spacing: 11) {
            Image(systemName: "book.pages")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ChurchTheme.olive)
                .frame(width: 34, height: 34)
                .background(ChurchTheme.surface, in: Circle())
            Text("Live Church Translation")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}
