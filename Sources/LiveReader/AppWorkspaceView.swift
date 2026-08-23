import RemoteSharingFeatureAPI
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
                    onImport: { showsAudioImporter = true },
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
            guard case .success(let urls) = result, let url = urls.first else {
                if case .failure(let error) = result {
                    libraryViewModel.presentedError = error.localizedDescription
                }
                return
            }
            selection = .library
            liveViewModel.setExternalSessionControlLock(true)
            Task {
                await libraryViewModel.importAudio(
                    from: url,
                    using: audioImporter,
                    liveSessionIsRunning: liveViewModel.isRunning
                )
                liveViewModel.setExternalSessionControlLock(false)
            }
        }
    }

    private var permissionPresentation: Binding<Bool> {
        Binding(
            get: { permissionCoordinator.isPresented },
            set: { isPresented in
                if !isPresented { permissionCoordinator.deferGuidance() }
            }
        )
    }

    private var brand: some View {
        HStack(spacing: 11) {
            Image(systemName: "book.pages")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ChurchTheme.olive)
                .frame(width: 34, height: 34)
                .background(ChurchTheme.surface, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("教会实时翻译")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                Text("本地语音翻译")
                    .font(.caption2)
                    .foregroundStyle(ChurchTheme.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case live
    case library

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "实时"
        case .library: "资料库"
        }
    }

    var icon: String {
        switch self {
        case .live: "waveform.and.mic"
        case .library: "books.vertical"
        }
    }
}
