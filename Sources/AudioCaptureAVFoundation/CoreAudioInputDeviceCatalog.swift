import AudioCaptureAPI
import CoreAudio
import Foundation

struct CoreAudioInputDevice: Sendable {
    let objectID: AudioDeviceID
    let metadata: AudioInputDevice
}

enum CoreAudioInputDeviceCatalog {
    static func devices() throws -> [CoreAudioInputDevice] {
        let defaultID = try CoreAudioPropertyReader.defaultInputDeviceID()
        return try CoreAudioPropertyReader.deviceIDs()
            .filter(CoreAudioPropertyReader.hasInputStreams)
            .map { deviceID in
                let inputID = AudioInputID(
                    rawValue: try CoreAudioPropertyReader.stringProperty(
                        kAudioDevicePropertyDeviceUID,
                        of: deviceID
                    ))
                let name = try CoreAudioPropertyReader.stringProperty(
                    kAudioObjectPropertyName,
                    of: deviceID
                )
                return CoreAudioInputDevice(
                    objectID: deviceID,
                    metadata: AudioInputDevice(
                        id: inputID,
                        name: name,
                        isDefault: deviceID == defaultID
                    )
                )
            }
            .sorted(by: deviceOrdering)
    }

    static func resolve(_ requestedID: AudioInputID?) throws -> CoreAudioInputDevice {
        let inputs = try devices()
        if let requestedID {
            guard let match = inputs.first(where: { $0.metadata.id == requestedID }) else {
                throw AudioCaptureError.deviceNotFound(requestedID)
            }
            return match
        }
        guard let fallback = inputs.first(where: \.metadata.isDefault) ?? inputs.first else {
            throw AudioCaptureError.invalidConfiguration("No audio input is available.")
        }
        return fallback
    }

    private static func deviceOrdering(
        _ left: CoreAudioInputDevice,
        _ right: CoreAudioInputDevice
    ) -> Bool {
        if left.metadata.isDefault != right.metadata.isDefault {
            return left.metadata.isDefault
        }
        return left.metadata.name.localizedCaseInsensitiveCompare(right.metadata.name)
            == .orderedAscending
    }
}
