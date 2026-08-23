import ASRQualificationSupport
import Foundation
import VADAPI

enum QwenQualificationEndReason {
    static func map(_ value: String) throws -> SpeechSegmentEndReason {
        switch value {
        case "trailingSilence": .trailingSilence
        case "softSilence": .softSilence
        case "maximumBoundary": .maximumBoundary
        case "maximumDuration": .maximumDuration
        case "endOfStream": .endOfStream
        default: throw QwenQualificationSegmentError.unknownEndReason(value)
        }
    }

    static func speechSegment(
        loaded: ASRQualificationLoadedSegment,
        sampleRate: Int
    ) throws -> SpeechSegment {
        let definition = loaded.definition
        guard let sequence = UInt64(exactly: definition.sequence) else {
            throw QwenQualificationSegmentError.invalidSequence(definition.sequence)
        }
        return SpeechSegment(
            sequenceNumber: sequence,
            samples: loaded.samples,
            sampleRate: Double(sampleRate),
            startedAt: .seconds(Double(definition.startSample) / Double(sampleRate)),
            endedAt: .seconds(Double(definition.endSample) / Double(sampleRate)),
            endReason: try map(definition.endReason)
        )
    }
}

enum QwenQualificationSegmentError: Error, Equatable {
    case unknownEndReason(String)
    case invalidSequence(Int)
    case unsafeClipID(String)
}

enum QwenQualificationWAVLocator {
    static func url(for clipID: String, in directory: URL) throws -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard !clipID.isEmpty,
            clipID.unicodeScalars.allSatisfy(allowed.contains),
            clipID != ".",
            clipID != ".."
        else {
            throw QwenQualificationSegmentError.unsafeClipID(clipID)
        }
        return directory.appendingPathComponent(clipID).appendingPathExtension("wav")
    }
}
