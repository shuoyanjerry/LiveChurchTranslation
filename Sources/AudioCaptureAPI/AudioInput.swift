/// A stable identifier for an audio input device.
public struct AudioInputID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// User-presentable metadata for an available audio input.
public struct AudioInputDevice: Identifiable, Equatable, Sendable {
    public let id: AudioInputID
    public let name: String
    public let isDefault: Bool

    public init(id: AudioInputID, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

/// The operating system's current microphone authorization decision.
public enum AudioCapturePermission: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized
}

/// Immutable parameters for one capture stream.
public struct AudioCaptureRequest: Equatable, Sendable {
    public let deviceID: AudioInputID?
    public let bufferDuration: Duration

    public init(
        deviceID: AudioInputID? = nil,
        bufferDuration: Duration = .milliseconds(40)
    ) {
        self.deviceID = deviceID
        self.bufferDuration = bufferDuration
    }
}
