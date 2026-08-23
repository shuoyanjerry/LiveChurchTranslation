import ASRQualificationSupport
import Foundation
import VADAPI

enum FunQualificationSegmentFactory {
    static func speechSegment(
        loaded: ASRQualificationLoadedSegment,
        sampleRate: Int
    ) throws -> SpeechSegment {
        let definition = loaded.definition
        guard let sequence = UInt64(exactly: definition.sequence) else {
            throw FunQualificationSegmentError.invalidSequence
        }
        return SpeechSegment(
            sequenceNumber: sequence,
            samples: loaded.samples,
            sampleRate: Double(sampleRate),
            startedAt: .seconds(Double(definition.startSample) / Double(sampleRate)),
            endedAt: .seconds(Double(definition.endSample) / Double(sampleRate)),
            endReason: try endReason(definition.endReason)
        )
    }

    private static func endReason(_ value: String) throws -> SpeechSegmentEndReason {
        switch value {
        case "trailingSilence": .trailingSilence
        case "softSilence": .softSilence
        case "maximumBoundary": .maximumBoundary
        case "maximumDuration": .maximumDuration
        case "endOfStream": .endOfStream
        default: throw FunQualificationSegmentError.unknownEndReason
        }
    }
}

enum FunQualificationSegmentError: Error, Equatable {
    case unknownEndReason
    case invalidSequence
    case unsafeClipID
}

enum FunQualificationWAVLocator {
    static func url(for clipID: String, in directory: URL) throws -> URL {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard !clipID.isEmpty,
            clipID.unicodeScalars.allSatisfy(allowed.contains),
            clipID != ".",
            clipID != ".."
        else {
            throw FunQualificationSegmentError.unsafeClipID
        }
        return directory.appendingPathComponent(clipID).appendingPathExtension("wav")
    }
}
