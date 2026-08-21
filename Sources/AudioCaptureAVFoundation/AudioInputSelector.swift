import AVFoundation
import AudioCaptureAPI
import AudioToolbox
import CoreAudio

enum AudioInputSelector {
    static func select(
        _ deviceID: AudioDeviceID,
        on inputNode: AVAudioInputNode
    ) throws {
        guard let audioUnit = inputNode.audioUnit else {
            throw AudioCaptureError.invalidConfiguration("The input audio unit is unavailable.")
        }
        var mutableDeviceID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioCaptureError.systemFailure(
                operation: "selecting the audio input",
                status: status
            )
        }
    }
}
