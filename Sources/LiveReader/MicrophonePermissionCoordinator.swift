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
    private let requestTimeout: Duration
    private var isSuppressed = false
    private var operationRevision = 0

    public init(
        permissionClient: any MicrophonePermissionClient,
        settingsOpener: any MicrophoneSettingsOpening,
        requestTimeout: Duration = .seconds(20)
    ) {
        self.permissionClient = permissionClient
        self.settingsOpener = settingsOpener
        self.requestTimeout = requestTimeout
    }

    public func load() async {
        await refresh()
    }

    public func refresh() async {
        if isRequesting {
            let permission = await permissionClient.authorizationStatus()
            guard isRequesting, permission != .notDetermined else { return }
            operationRevision += 1
            isRequesting = false
            apply(permission)
            return
        }
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
        let permission = await requestPermissionWithTimeout()
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

    private func requestPermissionWithTimeout() async -> AudioCapturePermission {
        let (stream, continuation) = AsyncStream.makeStream(
            of: AudioCapturePermission.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        let requestTask = Task { [permissionClient] in
            continuation.yield(await permissionClient.requestPermission())
        }
        let timeoutTask = Task { [permissionClient, requestTimeout] in
            do {
                try await Task.sleep(for: requestTimeout)
            } catch {
                return
            }
            continuation.yield(await permissionClient.authorizationStatus())
        }
        defer {
            requestTask.cancel()
            timeoutTask.cancel()
            continuation.finish()
        }
        return await withTaskCancellationHandler {
            for await permission in stream {
                return permission
            }
            return await permissionClient.authorizationStatus()
        } onCancel: {
            continuation.finish()
        }
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
