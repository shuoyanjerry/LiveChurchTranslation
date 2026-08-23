import AudioCaptureAPI
import Combine

public enum MicrophonePermissionGuidance: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
}

@MainActor
public final class MicrophonePermissionCoordinator: ObservableObject {
    @Published public private(set) var guidance: MicrophonePermissionGuidance?
    @Published public private(set) var isPresented = false
    @Published public private(set) var isRequesting = false

    private let permissionClient: any MicrophonePermissionClient
    private let settingsOpener: any MicrophoneSettingsOpening
    private var isSuppressed = false
    private var operationRevision = 0

    public init(
        permissionClient: any MicrophonePermissionClient,
        settingsOpener: any MicrophoneSettingsOpening
    ) {
        self.permissionClient = permissionClient
        self.settingsOpener = settingsOpener
    }

    public func load() async {
        await refresh()
    }

    public func refresh() async {
        guard !isRequesting else { return }
        operationRevision += 1
        let revision = operationRevision
        let permission = await permissionClient.authorizationStatus()
        guard revision == operationRevision else { return }
        apply(permission)
    }

    public func requestAccess() async {
        guard guidance == .notDetermined, !isRequesting else { return }
        operationRevision += 1
        let revision = operationRevision
        isRequesting = true
        let permission = await permissionClient.requestPermission()
        guard revision == operationRevision else { return }
        isRequesting = false
        apply(permission)
    }

    public func openSystemSettings() {
        settingsOpener.openMicrophoneSettings()
    }

    public func deferGuidance() {
        isSuppressed = true
        isPresented = false
    }

    private func apply(_ permission: AudioCapturePermission) {
        switch permission {
        case .authorized:
            guidance = nil
            isPresented = false
            isSuppressed = false
        case .notDetermined:
            guidance = .notDetermined
            isPresented = !isSuppressed
        case .denied:
            guidance = .denied
            isPresented = !isSuppressed
        case .restricted:
            guidance = .restricted
            isPresented = !isSuppressed
        }
    }
}
