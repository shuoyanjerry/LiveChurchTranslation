import AudioCaptureAPI
import LiveReader

actor PermissionClientFake: MicrophonePermissionClient {
    private var permission: AudioCapturePermission
    private let requestResult: AudioCapturePermission
    private let requestDelay: Duration?
    private var checks = 0
    private var requests = 0

    init(
        permission: AudioCapturePermission,
        requestResult: AudioCapturePermission? = nil,
        requestDelay: Duration? = nil
    ) {
        self.permission = permission
        self.requestResult = requestResult ?? permission
        self.requestDelay = requestDelay
    }

    func authorizationStatus() -> AudioCapturePermission {
        checks += 1
        return permission
    }

    func requestPermission() async -> AudioCapturePermission {
        requests += 1
        if let requestDelay {
            try? await Task.sleep(for: requestDelay)
        }
        permission = requestResult
        return permission
    }

    func setPermission(_ permission: AudioCapturePermission) {
        self.permission = permission
    }

    func authorizationChecks() -> Int { checks }
    func permissionRequests() -> Int { requests }
}

@MainActor
final class SettingsOpenerFake: MicrophoneSettingsOpening {
    private(set) var openCount = 0

    func openMicrophoneSettings() {
        openCount += 1
    }
}
