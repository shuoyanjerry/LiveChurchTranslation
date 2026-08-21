import Foundation

struct AppDirectories: Sendable {
    let root: URL
    let models: URL
    let glossary: URL
    let transcripts: URL
    let diagnostics: URL

    static func production(fileManager: FileManager = .default) throws -> AppDirectories {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = applicationSupport.appending(
            path: "LiveChurchTranslation",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return AppDirectories(
            root: root,
            models: root.appending(path: "Models", directoryHint: .isDirectory),
            glossary: root.appending(path: "Glossary", directoryHint: .isDirectory),
            transcripts: root.appending(path: "Transcripts", directoryHint: .isDirectory),
            diagnostics: root.appending(path: "Diagnostics", directoryHint: .isDirectory)
        )
    }
}
