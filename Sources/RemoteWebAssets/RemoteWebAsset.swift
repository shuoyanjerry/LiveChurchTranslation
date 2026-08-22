import Foundation
import RemoteWebAssetsAPI

public enum RemoteWebAssetCatalog {
    public static func asset(for requestPath: String) -> RemoteWebAsset? {
        switch requestPath {
        case "/", "/index.html": make(type: "text/html; charset=utf-8", text: ReaderHTML.value)
        case "/reader.css": make(type: "text/css; charset=utf-8", text: ReaderCSS.value)
        case "/reader.js": make(type: "text/javascript; charset=utf-8", text: ReaderJavaScript.value)
        default: nil
        }
    }

    private static func make(type: String, text: String) -> RemoteWebAsset {
        RemoteWebAsset(contentType: type, body: Data(text.utf8))
    }
}

public struct BundledRemoteWebAssetProvider: RemoteWebAssetProviding {
    public init() {}

    public func asset(for requestPath: String) -> RemoteWebAsset? {
        RemoteWebAssetCatalog.asset(for: requestPath)
    }
}
