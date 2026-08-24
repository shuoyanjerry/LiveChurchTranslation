@preconcurrency import AVFoundation
import Foundation

@MainActor
extension VideoFixtureWriter {
    func makeAudioPipeline() async throws -> VideoFixtureAudioPipeline? {
        guard let audioURL else { return nil }
        let asset = AVURLAsset(url: audioURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw VideoFixtureError.missingTrack("audio source")
        }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        guard reader.canAdd(output) else {
            throw VideoFixtureError.cannotAddTrack("audio reader")
        }
        reader.add(output)
        let input = makeAudioInput()
        guard writer.canAdd(input) else {
            throw VideoFixtureError.cannotAddTrack("audio writer")
        }
        writer.add(input)
        return VideoFixtureAudioPipeline(reader: reader, output: output, input: input)
    }

    func appendAudio(pipeline: VideoFixtureAudioPipeline) async throws {
        while let sample = pipeline.output.copyNextSampleBuffer() {
            try await waitUntilReady(pipeline.input)
            guard pipeline.input.append(sample) else {
                throw writer.error ?? VideoFixtureError.writerFailed("append audio")
            }
        }
        guard pipeline.reader.status == .completed else {
            throw pipeline.reader.error ?? VideoFixtureError.readerFailed("decode audio")
        }
    }

    private func makeAudioInput() -> AVAssetWriterInput {
        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000,
            ]
        )
        input.expectsMediaDataInRealTime = false
        return input
    }
}

struct VideoFixtureAudioPipeline {
    let reader: AVAssetReader
    let output: AVAssetReaderTrackOutput
    let input: AVAssetWriterInput
}
