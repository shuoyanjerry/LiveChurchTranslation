import Foundation

enum ArchitectureFailure: Error {
    case invalidPackageDump
}

struct TargetNode {
    let name: String
    let type: String
    let dependencies: [String]
}

let data = FileHandle.standardInput.readDataToEndOfFile()
guard
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
    let rawTargets = root["targets"] as? [[String: Any]]
else {
    throw ArchitectureFailure.invalidPackageDump
}

let localNames = Set(rawTargets.compactMap { $0["name"] as? String })
let targets = try rawTargets.map { raw -> TargetNode in
    guard let name = raw["name"] as? String, let type = raw["type"] as? String else {
        throw ArchitectureFailure.invalidPackageDump
    }
    let dependencies: [String] = (raw["dependencies"] as? [[String: Any]] ?? []).compactMap { value in
        guard let pair = value["byName"] as? [Any], let dependency = pair.first as? String else {
            return nil
        }
        return localNames.contains(dependency) ? dependency : nil
    }
    return TargetNode(name: name, type: type, dependencies: dependencies)
}

var failures: [String] = []
let graph: [String: [String]] = Dictionary(
    uniqueKeysWithValues: targets.map { ($0.name, $0.dependencies) }
)

func isAPI(_ name: String) -> Bool {
    name.hasSuffix("API")
}

func isAllowed(_ source: TargetNode, dependency: String) -> Bool {
    if source.name == "ChurchTranslatorApp" { return true }
    if source.name == "ChurchTranslatorCLI" && dependency == "ChurchTranslatorApp" {
        return true
    }
    if source.name == "VADWebRTC" && dependency == "WebRTCVADC" {
        return true
    }
    if source.type == "test" {
        return dependency != "ChurchTranslatorApp" && graph[dependency] != nil
    }
    if source.name == "LiveReader" {
        return isAPI(dependency) || dependency == "UIDesignSystem"
    }
    if source.name == "UIDesignSystem" {
        return isAPI(dependency)
    }
    return isAPI(dependency)
}

for target in targets {
    for dependency in target.dependencies where !isAllowed(target, dependency: dependency) {
        failures.append(
            "target \(target.name) must not depend on implementation target \(dependency)"
        )
    }
}

enum VisitState {
    case visiting
    case visited
}

var visitStates: [String: VisitState] = [:]
var path: [String] = []

func visit(_ name: String) {
    if visitStates[name] == .visiting {
        let cycleStart = path.firstIndex(of: name) ?? path.startIndex
        let cycle = (path[cycleStart...] + [name]).joined(separator: " -> ")
        failures.append("target dependency cycle: " + cycle)
        return
    }
    if visitStates[name] == .visited { return }
    visitStates[name] = .visiting
    path.append(name)
    for dependency in graph[name] ?? [] {
        visit(dependency)
    }
    _ = path.popLast()
    visitStates[name] = .visited
}

for target in targets {
    visit(target.name)
}

if failures.isEmpty {
    print("Target dependency graph: OK (\(targets.count) targets)")
} else {
    for failure in Set(failures).sorted() {
        FileHandle.standardError.write(Data("architecture: \(failure)\n".utf8))
    }
    exit(1)
}
