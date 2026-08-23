import Foundation

struct V3SelectedVADInputs: Equatable {
    let workspaceRoot: URL
    let outputURL: URL?

    init(
        environment: [String: String],
        workspaceRoot: URL = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
    ) throws {
        let supplied = environment.keys.filter { $0.hasPrefix(Self.prefix) }
        if let unsupported = supplied.sorted().first(where: { !Self.allowedKeys.contains($0) }) {
            throw V3SelectedVADError.unsupportedEnvironment(unsupported)
        }
        self.workspaceRoot = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        if let raw = environment[Self.outputKey] {
            guard !raw.isEmpty, !raw.allSatisfy(\.isWhitespace) else {
                throw V3SelectedVADError.missingOutput
            }
            outputURL = URL(fileURLWithPath: raw).standardizedFileURL
            try validateOutput()
        } else {
            outputURL = nil
        }
    }

    var manifestURL: URL {
        workspaceRoot.appendingPathComponent(
            ".artifacts/sermon-corpus/wav-v3/replay-manifest.json"
        )
    }

    var validationURL: URL {
        workspaceRoot.appendingPathComponent(".artifacts/sermon-corpus/wav-v3.validation.json")
    }

    var sourceManifestURL: URL {
        workspaceRoot.appendingPathComponent(
            ".artifacts/sermon-corpus/online-sermon-corpus-manifest.json"
        )
    }

    var sourceSchemaURL: URL {
        workspaceRoot.appendingPathComponent("Docs/OnlineSermonCorpusManifest.schema.json")
    }

    var builderURL: URL {
        workspaceRoot.appendingPathComponent(
            ".artifacts/sermon-corpus/build_wav_v3_replay_media.py"
        )
    }

    var corpusRootURL: URL { manifestURL.deletingLastPathComponent() }

    static func shouldPreflight(_ environment: [String: String]) -> Bool {
        environment[preflightKey] == "1"
    }

    static func shouldReplay(_ environment: [String: String]) -> Bool {
        environment[outputKey] != nil
    }

    private func validateOutput() throws {
        guard let outputURL else { return }
        let expectedParent = workspaceRoot.appendingPathComponent(
            ".artifacts/v3-selected-vad",
            isDirectory: true
        ).standardizedFileURL
        let name = outputURL.lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard outputURL.deletingLastPathComponent().standardizedFileURL == expectedParent,
            outputURL.pathExtension == "json", name.count <= 128,
            name.first?.isLetter == true, !name.contains(".."),
            name.unicodeScalars.allSatisfy(allowed.contains)
        else { throw V3SelectedVADError.unsafeOutput }
    }

    static let prefix = "V3_SELECTED_VAD_"
    static let outputKey = prefix + "OUTPUT"
    static let preflightKey = prefix + "PREFLIGHT"
    static let allowedKeys = Set([outputKey, preflightKey])
}
