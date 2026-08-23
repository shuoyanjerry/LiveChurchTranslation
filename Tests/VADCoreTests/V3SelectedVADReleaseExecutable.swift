import Darwin
import Foundation

enum V3SelectedVADReleaseExecutable {
    static func fingerprint() throws -> V3SelectedVADFingerprint {
        try V3SelectedVADHashing.fingerprint(loadedURL())
    }

    private static func loadedURL() throws -> URL {
        let expectedName = "LiveChurchTranslationPackageTests"
        let candidates = (0..<_dyld_image_count()).compactMap { index -> URL? in
            guard let path = _dyld_get_image_name(index) else { return nil }
            let bytes = UnsafeBufferPointer(
                start: UnsafeRawPointer(path).assumingMemoryBound(to: UInt8.self),
                count: Int(strlen(path))
            )
            guard let string = String(bytes: bytes, encoding: .utf8) else { return nil }
            let url = URL(fileURLWithPath: string).resolvingSymlinksInPath().standardizedFileURL
            return url.lastPathComponent == expectedName ? url : nil
        }
        guard candidates.count == 1, candidates[0].path.contains("/release/") else {
            throw V3SelectedVADError.provenanceMismatch("release test executable")
        }
        return candidates[0]
    }
}
