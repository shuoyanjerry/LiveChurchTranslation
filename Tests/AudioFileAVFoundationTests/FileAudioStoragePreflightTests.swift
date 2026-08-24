@testable import AudioFileAVFoundation
import Testing

@Suite struct FileAudioStoragePreflightTests {
    @Test func includesFixedHeadroomForDecodedPCM() {
        let required: UInt64 = 1_000_000_000
        let minimum = required + FileAudioStoragePreflight.safetyMarginBytes

        #expect(throws: Never.self) {
            try FileAudioStoragePreflight.validate(
                requiredBytes: required,
                availableBytes: minimum
            )
        }
        #expect(
            throws: FileAudioCaptureError.insufficientStorage(
                requiredBytes: minimum,
                availableBytes: minimum - 1
            )
        ) {
            try FileAudioStoragePreflight.validate(
                requiredBytes: required,
                availableBytes: minimum - 1
            )
        }
    }

    @Test func usesProportionalHeadroomForLargeImports() {
        let required: UInt64 = 20_000_000_000
        let minimum: UInt64 = 22_000_000_000

        #expect(throws: Never.self) {
            try FileAudioStoragePreflight.validate(
                requiredBytes: required,
                availableBytes: minimum
            )
        }
        #expect(throws: FileAudioCaptureError.self) {
            try FileAudioStoragePreflight.validate(
                requiredBytes: required,
                availableBytes: minimum - 1
            )
        }
    }
}
