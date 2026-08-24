@preconcurrency import AVFoundation
import CoreVideo
import Darwin
import Foundation

@MainActor
final class VideoFixtureWriter {
    let outputURL: URL
    let writer: AVAssetWriter
    let videoInput: AVAssetWriterInput
    let videoAdaptor: AVAssetWriterInputPixelBufferAdaptor
    let audioURL: URL?

    init(outputURL: URL, fileType: AVFileType, audioURL: URL?) throws {
        self.outputURL = outputURL
        self.audioURL = audioURL
        writer = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
        videoInput = Self.makeVideoInput()
        videoAdaptor = Self.makeVideoAdaptor(input: videoInput)
        guard writer.canAdd(videoInput) else {
            throw VideoFixtureError.cannotAddTrack("video")
        }
        writer.add(videoInput)
    }

    func write() async throws -> URL {
        let audioPipeline = try await makeAudioPipeline()
        try start(audioPipeline: audioPipeline)
        do {
            try await appendVideoFrames()
            videoInput.markAsFinished()
            if let audioPipeline {
                try await appendAudio(pipeline: audioPipeline)
                audioPipeline.input.markAsFinished()
            }
        } catch {
            audioPipeline?.reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
        try await finish()
        return outputURL
    }

    private func start(audioPipeline: VideoFixtureAudioPipeline?) throws {
        guard writer.startWriting() else {
            throw writer.error ?? VideoFixtureError.writerFailed("startWriting")
        }
        writer.startSession(atSourceTime: .zero)
        if let reader = audioPipeline?.reader, !reader.startReading() {
            writer.cancelWriting()
            throw reader.error ?? VideoFixtureError.readerFailed("startReading")
        }
    }

    private func finish() async throws {
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else {
            throw writer.error ?? VideoFixtureError.writerFailed("finishWriting")
        }
    }

    private static func makeVideoInput() -> AVAssetWriterInput {
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 160,
                AVVideoHeightKey: 90,
            ]
        )
        input.expectsMediaDataInRealTime = false
        return input
    }

    private static func makeVideoAdaptor(
        input: AVAssetWriterInput
    ) -> AVAssetWriterInputPixelBufferAdaptor {
        AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 160,
                kCVPixelBufferHeightKey as String: 90,
            ]
        )
    }
}

extension VideoFixtureWriter {
    private func appendVideoFrames() async throws {
        guard let pool = videoAdaptor.pixelBufferPool else {
            throw VideoFixtureError.pixelBufferUnavailable
        }
        for frame in 0..<3 {
            try await waitUntilReady(videoInput)
            let pixelBuffer = try makePixelBuffer(pool: pool, shade: frame * 64)
            let presentationTime = CMTime(value: CMTimeValue(frame), timescale: 4)
            guard videoAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw writer.error ?? VideoFixtureError.writerFailed("append video")
            }
        }
    }

    private func makePixelBuffer(
        pool: CVPixelBufferPool,
        shade: Int
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw VideoFixtureError.pixelBufferUnavailable
        }
        fill(pixelBuffer: pixelBuffer, shade: shade)
        return pixelBuffer
    }

    private func fill(pixelBuffer: CVPixelBuffer, shade: Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let address = CVPixelBufferGetBaseAddress(pixelBuffer) {
            let byteCount =
                CVPixelBufferGetBytesPerRow(pixelBuffer)
                * CVPixelBufferGetHeight(pixelBuffer)
            memset(address, Int32(shade), byteCount)
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }

    func waitUntilReady(_ input: AVAssetWriterInput) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing else {
                throw writer.error ?? VideoFixtureError.writerFailed("write samples")
            }
            guard clock.now < deadline else {
                throw VideoFixtureError.writerTimedOut
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
}

enum VideoFixtureError: Error {
    case cannotAddTrack(String)
    case missingTrack(String)
    case pixelBufferUnavailable
    case readerFailed(String)
    case writerFailed(String)
    case writerTimedOut
}
