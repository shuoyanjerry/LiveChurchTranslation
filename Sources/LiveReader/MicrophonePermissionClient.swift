import AppKit
import AudioCaptureAPI
import Foundation

public protocol MicrophonePermissionClient: Sendable {
    func authorizationStatus() async -> AudioCapturePermission
    func requestPermission() async -> AudioCapturePermission
}

public struct AudioCaptureMicrophonePermissionClient: MicrophonePermissionClient {
    private let capture: any AudioCaptureProvider

    public init(capture: any AudioCaptureProvider) {
        self.capture = capture
    }

    public func authorizationStatus() async -> AudioCapturePermission {
        await capture.authorizationStatus()
    }

    public func requestPermission() async -> AudioCapturePermission {
        await capture.requestPermission()
    }
}

@MainActor
public protocol MicrophoneSettingsOpening: Sendable {
    func openMicrophoneSettings()
}

public struct MacMicrophoneSettingsOpener: MicrophoneSettingsOpening {
    public init() {}

    public func openMicrophoneSettings() {
        guard
            let url = URL(
                string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            )
        else { return }
        _ = NSWorkspace.shared.open(url)
    }
}
