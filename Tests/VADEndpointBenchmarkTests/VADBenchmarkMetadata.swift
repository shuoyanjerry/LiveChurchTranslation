import Darwin
import Foundation
import VADAPI

struct VADBenchmarkEnvironmentMetadata: Encodable {
    let operatingSystem: String
    let architecture: String
    let hardwareModel: String?
    let processorCount: Int
    let physicalMemoryBytes: UInt64
    let buildConfiguration: String
    let swiftVersion: String?
    let repositoryRevision: String?
    let repositoryHasUncommittedChanges: Bool?

    static func current() -> Self {
        let revision = command("/usr/bin/git", ["rev-parse", "HEAD"])
        let status = command("/usr/bin/git", ["status", "--porcelain"])
        return Self(
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: architectureName,
            hardwareModel: sysctlString("hw.model"),
            processorCount: ProcessInfo.processInfo.processorCount,
            physicalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            buildConfiguration: buildConfigurationName,
            swiftVersion: command("/usr/bin/swift", ["--version"]),
            repositoryRevision: revision,
            repositoryHasUncommittedChanges: status.map { !$0.isEmpty }
        )
    }

    private static func command(_ executable: String, _ arguments: [String]) -> String? {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        let utf8 = bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(bytes: utf8, encoding: .utf8)
    }

    private static var architectureName: String {
        #if arch(arm64)
            "arm64"
        #elseif arch(x86_64)
            "x86_64"
        #else
            "unknown"
        #endif
    }

    private static var buildConfigurationName: String {
        #if DEBUG
            "debug"
        #else
            "release"
        #endif
    }
}

struct VADStrategyMetadata: Encodable {
    let classifier: String
    let classifierMode: Int?
    let libfvadRevision: String?
    let policy: [String: Double]
    let classifierParameters: [String: Double]
}

extension VoiceActivityConfiguration {
    var benchmarkValues: [String: Double] {
        [
            "analysisWindowMs": analysisWindow.milliseconds,
            "decisionSpeechVotes": Double(decisionSpeechVotes),
            "decisionWindowCount": Double(decisionWindowCount),
            "maximumBoundaryGraceMs": maximumBoundaryGrace.milliseconds,
            "minimumVoicedMs": minimumVoiced.milliseconds,
            "postRollMs": postRoll.milliseconds,
            "preRollMs": preRoll.milliseconds,
            "preferredBoundarySilenceMs": preferredBoundarySilence.milliseconds,
            "preferredMaximumSegmentMs": preferredMaximumSegment.milliseconds,
            "requiredSampleRateHz": requiredSampleRate,
            "shortTrailingSilenceMs": shortTrailingSilence.milliseconds,
            "shortUtteranceMs": shortUtterance.milliseconds,
            "softSplitAfterMs": softSplitAfter.milliseconds,
            "softSplitSilenceMs": softSplitSilence.milliseconds,
            "speechStartMs": speechStart.milliseconds,
            "trailingSilenceMs": trailingSilence.milliseconds,
        ]
    }
}

extension Duration {
    fileprivate var milliseconds: Double {
        Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }
}
