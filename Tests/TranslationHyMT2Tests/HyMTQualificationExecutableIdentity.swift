import Darwin
import Foundation
import TranslationQualificationSupport

enum HyMTQualificationExecutableIdentity {
    private static let executableName = "LiveChurchTranslationPackageTests"

    static func capture(
        requireRelease: Bool = true
    ) throws -> TranslationQualificationArtifactDigest {
        let url = try loadedTestExecutableURL()
        if requireRelease {
            guard url.path.contains("/release/"),
                url.lastPathComponent == executableName
            else {
                throw TranslationQualificationError.invalidReport(
                    "qualification is not running from the release test executable"
                )
            }
        }
        return try HyMTQualificationFileHasher.artifact(url)
    }

    private static func loadedTestExecutableURL() throws -> URL {
        let candidates = (0..<_dyld_image_count()).compactMap { index -> URL? in
            guard let name = _dyld_get_image_name(index) else { return nil }
            let bytes = UnsafeBufferPointer(
                start: UnsafeRawPointer(name).assumingMemoryBound(to: UInt8.self),
                count: Int(strlen(name))
            )
            guard let path = String(bytes: bytes, encoding: .utf8) else { return nil }
            let url = URL(fileURLWithPath: path)
                .resolvingSymlinksInPath().standardizedFileURL
            return url.lastPathComponent == executableName ? url : nil
        }
        guard candidates.count == 1 else {
            throw TranslationQualificationError.invalidReport(
                "qualification test executable identity is ambiguous"
            )
        }
        return candidates[0]
    }
}
