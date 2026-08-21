import AudioCaptureAPI
import CoreAudio

enum CoreAudioPropertyReader {
    static func deviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        try check(
            AudioObjectGetPropertyDataSize(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount
            ),
            operation: "enumerating audio devices"
        )
        let count = Int(byteCount) / MemoryLayout<AudioDeviceID>.stride
        var values = [AudioDeviceID](repeating: 0, count: count)
        guard !values.isEmpty else { return [] }
        let status = values.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return OSStatus(kAudioHardwareUnspecifiedError)
            }
            return AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount,
                baseAddress
            )
        }
        try check(status, operation: "reading audio devices")
        return values
    }

    static func defaultInputDeviceID() throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = AudioDeviceID(kAudioObjectUnknown)
        var byteCount = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &byteCount,
                &value
            ),
            operation: "reading the default input"
        )
        return value
    }

    static func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var byteCount: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(
            deviceID,
            &address,
            0,
            nil,
            &byteCount
        )
        return status == noErr && byteCount >= MemoryLayout<AudioStreamID>.size
    }

    static func stringProperty(
        _ selector: AudioObjectPropertySelector,
        of deviceID: AudioDeviceID
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let storage = UnsafeMutablePointer<Unmanaged<CFString>?>.allocate(capacity: 1)
        storage.initialize(to: nil)
        defer {
            storage.deinitialize(count: 1)
            storage.deallocate()
        }
        var byteCount = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &byteCount,
            UnsafeMutableRawPointer(storage)
        )
        try check(status, operation: "reading input metadata")
        guard let value = storage.pointee?.takeUnretainedValue() else {
            throw AudioCaptureError.invalidConfiguration("An input has no identifier.")
        }
        return value as String
    }

    private static func check(_ status: OSStatus, operation: String) throws {
        guard status == noErr else {
            throw AudioCaptureError.systemFailure(operation: operation, status: status)
        }
    }
}
