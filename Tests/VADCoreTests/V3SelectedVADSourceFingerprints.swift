import Foundation

enum V3SelectedVADSourceFingerprints {
    static func production(workspaceRoot: URL) throws -> V3SelectedVADSourceBundle {
        try V3SelectedVADHashing.sourceBundle(
            roots: [
                ("Sources/AudioProcessingAPI", ["swift"]),
                ("Sources/VADAPI", ["swift"]),
                ("Sources/VADCore", ["swift"]),
                ("Sources/VADWebRTC", ["swift"]),
                ("Sources/WebRTCVADC/Vendor/libfvad/src", ["c", "h"]),
                ("Sources/WebRTCVADC/Vendor/libfvad/include", ["c", "h"]),
            ],
            workspaceRoot: workspaceRoot
        )
    }

    static func harness(workspaceRoot: URL) throws -> V3SelectedVADSourceBundle {
        try V3SelectedVADHashing.sourceBundle(
            roots: [("Tests/VADCoreTests", ["swift"])],
            workspaceRoot: workspaceRoot,
            fileNamePrefix: "V3SelectedVAD"
        )
    }
}
