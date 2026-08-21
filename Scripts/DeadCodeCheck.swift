import Foundation

struct Declaration {
    let file: URL
    let line: Int
    let name: String
    let module: String
}

let rootPath =
    CommandLine.arguments.dropFirst().first
    ?? FileManager.default.currentDirectoryPath
let root = URL(fileURLWithPath: rootPath)
let sources = root.appending(path: "Sources")
let manager = FileManager.default
let keys: [URLResourceKey] = [.isRegularFileKey]
let enumerator = manager.enumerator(
    at: sources,
    includingPropertiesForKeys: keys,
    options: [.skipsHiddenFiles]
)

let access = #"^\s*(?:private|fileprivate)\s+"#
let modifiers = #"(?:static\s+)?"#
let declaration = #"(?:func|var|let|class|struct|enum|typealias)\s+"#
let identifier = #"([A-Za-z_][A-Za-z0-9_]*)"#
let pattern = access + modifiers + declaration + identifier
let declarationRegex = try NSRegularExpression(pattern: pattern)
var moduleSources: [String: String] = [:]
var declarations: [Declaration] = []

while let file = enumerator?.nextObject() as? URL {
    guard file.pathExtension == "swift",
        (try file.resourceValues(forKeys: Set(keys))).isRegularFile == true
    else { continue }
    let relative = file.path.replacingOccurrences(of: sources.path + "/", with: "")
    guard let module = relative.split(separator: "/").first.map(String.init) else { continue }
    let text = try String(contentsOf: file, encoding: .utf8)
    moduleSources[module, default: ""] += "\n" + text
    for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let value = String(line)
        let range = NSRange(value.startIndex..., in: value)
        guard let match = declarationRegex.firstMatch(in: value, range: range),
            let nameRange = Range(match.range(at: 1), in: value)
        else { continue }
        declarations.append(
            Declaration(file: file, line: index + 1, name: String(value[nameRange]), module: module)
        )
    }
}

var failures: [String] = []
for declaration in declarations {
    guard let text = moduleSources[declaration.module] else { continue }
    let escaped = NSRegularExpression.escapedPattern(for: declaration.name)
    let usageRegex = try NSRegularExpression(pattern: "\\b" + escaped + "\\b")
    let count = usageRegex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    if count == 1 {
        let relative = declaration.file.path.replacingOccurrences(of: root.path + "/", with: "")
        failures.append("\(relative):\(declaration.line): private '\(declaration.name)' is never referenced")
    }
}

if failures.isEmpty {
    print("Static private-declaration dead-code check: OK")
} else {
    for failure in failures.sorted() {
        FileHandle.standardError.write(Data("dead-code: \(failure)\n".utf8))
    }
    exit(1)
}
