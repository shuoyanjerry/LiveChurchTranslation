import ASRQualificationSupport
import Foundation

enum QwenQualificationHostEnvironment {
    static func detect(
        environment: [String: String]
    ) throws -> ASRQualificationEnvironmentV3 {
        ASRQualificationEnvironmentV3(
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            hardware: try command("/usr/sbin/sysctl", ["-n", "hw.model"]),
            architecture: architecture,
            buildConfiguration: buildConfiguration,
            repositoryRevision: try command(
                "/usr/bin/git",
                ["rev-parse", "HEAD"],
                in: repositoryRoot
            ),
            repositoryDirty: try !command(
                "/usr/bin/git",
                ["status", "--porcelain", "--untracked-files=normal"],
                in: repositoryRoot
            ).isEmpty,
            backgroundLoadNote: environment["QWEN_ASR_BACKGROUND_LOAD_NOTE"]
                ?? "Uncontrolled background processes; latency is not a clean-room measurement."
        )
    }

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var architecture: String {
        #if arch(arm64)
            "arm64"
        #else
            "unsupported-non-arm64"
        #endif
    }

    private static var buildConfiguration: String {
        #if DEBUG
            "debug"
        #else
            "release"
        #endif
    }

    private static func command(
        _ executable: String,
        _ arguments: [String],
        in directory: URL? = nil
    ) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw QwenQualificationEnvironmentError.commandFailed
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else {
            throw QwenQualificationEnvironmentError.commandFailed
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum QwenQualificationEnvironmentError: Error, Equatable {
    case commandFailed
}
