import Foundation

enum HyMT2ModelResolver {
    static func resolve(at location: URL, expectedFilename: String) throws -> URL {
        var isDirectory: ObjCBool = false
        guard
            FileManager.default.fileExists(
                atPath: location.path,
                isDirectory: &isDirectory
            )
        else {
            throw HyMT2Error.modelUnavailable(location.path)
        }
        if !isDirectory.boolValue {
            guard location.pathExtension.lowercased() == "gguf" else {
                throw HyMT2Error.modelUnavailable(location.path)
            }
            return location
        }

        let expected = location.appendingPathComponent(expectedFilename)
        if FileManager.default.fileExists(atPath: expected.path) {
            return expected
        }
        let candidates = try FileManager.default.contentsOfDirectory(
            at: location,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "gguf" }
        guard candidates.count == 1, let only = candidates.first else {
            throw HyMT2Error.modelUnavailable(expected.path)
        }
        return only
    }
}
