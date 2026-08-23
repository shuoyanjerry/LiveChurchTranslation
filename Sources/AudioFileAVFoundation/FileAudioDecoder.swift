import AVFoundation
import AudioCaptureAPI
import Foundation

actor FileAudioDecoder {
    private static let maximumSamplesPerChunk = 1_048_576

    private let url: URL
    private let file: AVAudioFile
    private let format: AVAudioFormat
    private let frameCapacity: AVAudioFrameCount
    private let ownsSecurityScope: Bool
    private var frameOffset: Int64 = 0
    private var isClosed = false

    static func open(url: URL, bufferSeconds: Double) throws -> FileAudioDecoder {
        guard url.isFileURL else { throw FileAudioCaptureError.invalidURL }
        let ownsScope = url.startAccessingSecurityScopedResource()
        do {
            return try FileAudioDecoder(
                url: url,
                bufferSeconds: bufferSeconds,
                ownsSecurityScope: ownsScope
            )
        } catch {
            if ownsScope { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }

    private init(
        url: URL,
        bufferSeconds: Double,
        ownsSecurityScope: Bool
    ) throws {
        self.url = url
        self.ownsSecurityScope = ownsSecurityScope
        do {
            file = try AVAudioFile(
                forReading: url,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
        } catch {
            throw FileAudioCaptureError.unreadableFile(url.lastPathComponent)
        }
        format = file.processingFormat
        guard format.commonFormat == .pcmFormatFloat32,
            format.sampleRate.isFinite,
            format.sampleRate > 0,
            format.channelCount > 0
        else {
            throw FileAudioCaptureError.unsupportedFormat("No Float32 PCM representation")
        }
        let frames = (bufferSeconds * format.sampleRate).rounded(.up)
        let sampleCount = frames * Double(format.channelCount)
        guard frames >= 1,
            frames <= Double(UInt32.max),
            sampleCount <= Double(Self.maximumSamplesPerChunk)
        else {
            throw AudioCaptureError.invalidConfiguration("Buffer duration is out of range.")
        }
        frameCapacity = AVAudioFrameCount(frames)
    }

    deinit {
        if ownsSecurityScope, !isClosed {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func nextFrame() throws -> AudioFrame? {
        if isClosed { return nil }
        do {
            try Task.checkCancellation()
            let remaining = file.length - file.framePosition
            guard remaining > 0 else {
                close()
                return nil
            }
            let readCount = AVAudioFrameCount(min(Int64(frameCapacity), remaining))
            let buffer = try makeBuffer(frameCapacity: readCount)
            try file.read(into: buffer, frameCount: readCount)
            try Task.checkCancellation()
            guard buffer.frameLength > 0 else {
                close()
                return nil
            }
            let result = try makeAudioFrame(
                from: buffer,
                format: format,
                frameOffset: frameOffset
            )
            frameOffset += Int64(buffer.frameLength)
            return result
        } catch is CancellationError {
            close()
            throw CancellationError()
        } catch let error as FileAudioCaptureError {
            close()
            throw error
        } catch {
            close()
            throw FileAudioCaptureError.decodingFailed(error.localizedDescription)
        }
    }

    func cancel() {
        close()
    }

    private func makeBuffer(frameCapacity: AVAudioFrameCount) throws -> AVAudioPCMBuffer {
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: frameCapacity
            )
        else {
            throw FileAudioCaptureError.unsupportedFormat("Invalid PCM buffer")
        }
        return buffer
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        if ownsSecurityScope { url.stopAccessingSecurityScopedResource() }
    }
}

private func makeAudioFrame(
    from buffer: AVAudioPCMBuffer,
    format: AVAudioFormat,
    frameOffset: Int64
) throws -> AudioFrame {
    let channels = Int(format.channelCount)
    let frames = Int(buffer.frameLength)
    guard let channelData = buffer.floatChannelData else {
        throw FileAudioCaptureError.unsupportedFormat("Missing Float32 channel data")
    }
    let samples: [Float]
    if format.isInterleaved {
        samples = Array(
            UnsafeBufferPointer(
                start: channelData[0],
                count: frames * channels
            )
        )
    } else {
        var interleaved = [Float]()
        interleaved.reserveCapacity(frames * channels)
        for frame in 0..<frames {
            for channel in 0..<channels {
                interleaved.append(channelData[channel][frame])
            }
        }
        samples = interleaved
    }
    return AudioFrame(
        samples: samples,
        sampleRate: format.sampleRate,
        channelCount: channels,
        timestamp: audioTimestamp(for: frameOffset, sampleRate: format.sampleRate)
    )
}

private func audioTimestamp(for offset: Int64, sampleRate: Double) -> Duration {
    let value = Double(offset) / sampleRate
    let seconds = value.rounded(.down)
    let attoseconds = ((value - seconds) * 1e18).rounded()
    return Duration(
        secondsComponent: Int64(seconds),
        attosecondsComponent: Int64(attoseconds)
    )
}
