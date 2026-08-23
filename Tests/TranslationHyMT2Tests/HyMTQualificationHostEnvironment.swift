import Foundation
import TranslationQualificationSupport

enum HyMTQualificationHostEnvironment {
    static func capture(backgroundLoad: String) -> TranslationQualificationEnvironment {
        TranslationQualificationEnvironment(
            hardware: command("/usr/sbin/sysctl", ["-n", "hw.model"]),
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            repositoryRevision: repositoryRevision(),
            backgroundLoad: backgroundLoad
        )
    }

    private static func repositoryRevision() -> String {
        let revision = command("/usr/bin/git", ["rev-parse", "HEAD"])
        let status = command("/usr/bin/git", ["status", "--porcelain"])
        return status == "clean" ? revision : "\(revision)+dirty"
    }

    private static func command(_ executable: String, _ arguments: [String]) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "unavailable" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let value = (String(data: data, encoding: .utf8) ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "clean" : value
        } catch {
            return "unavailable"
        }
    }
}
