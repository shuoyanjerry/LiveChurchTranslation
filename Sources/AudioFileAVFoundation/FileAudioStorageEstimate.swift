import AVFoundation
import Foundation

func pcm16StorageBytes(
    frameCount: Int64,
    channelCount: AVAudioChannelCount
) throws -> UInt64 {
    guard frameCount >= 0 else {
        throw FileAudioCaptureError.unsupportedFormat("无法确定音轨长度")
    }
    let samples = UInt64(frameCount).multipliedReportingOverflow(
        by: UInt64(channelCount)
    )
    let bytes = samples.partialValue.multipliedReportingOverflow(
        by: UInt64(MemoryLayout<Int16>.size)
    )
    guard !samples.overflow, !bytes.overflow else {
        throw FileAudioCaptureError.unsupportedFormat("音轨过长")
    }
    let total = bytes.partialValue.addingReportingOverflow(68)
    guard !total.overflow else {
        throw FileAudioCaptureError.unsupportedFormat("音轨过长")
    }
    return total.partialValue
}

func fileAudioTimestamp(for offset: Int64, sampleRate: Double) -> Duration {
    let value = Double(offset) / sampleRate
    let seconds = value.rounded(.down)
    let attoseconds = ((value - seconds) * 1e18).rounded()
    return Duration(
        secondsComponent: Int64(seconds),
        attosecondsComponent: Int64(attoseconds)
    )
}
