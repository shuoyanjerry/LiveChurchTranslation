import Darwin
import Foundation
import ScriptureQualificationSupport

@main
enum ScriptureQualificationTool {
    static func main() {
        do {
            try run(arguments: Array(ProcessInfo.processInfo.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("preflight failed: \(error.localizedDescription)\n".utf8))
            exit(EXIT_FAILURE)
        }
    }

    private static func run(arguments: [String]) throws {
        guard arguments.count == 4, arguments[0] == "verify" else {
            throw ToolError.usage
        }
        let root = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let manifest = URL(fileURLWithPath: arguments[2])
        let corpus = try ScriptureQualificationCorpusLoader.load(
            manifestURL: manifest,
            privateRoot: root,
            expectedManifestSHA256: arguments[3]
        )
        print(
            "preflight passed: corpus=\(corpus.manifest.corpusID) "
                + "items=\(corpus.items.count) pairs=\(corpus.manifest.translationPairs.count)"
        )
    }
}

private enum ToolError: LocalizedError {
    case usage

    var errorDescription: String? {
        "usage: scripture-qualification-tool verify <private-root> <manifest> <expected-sha256>"
    }
}
