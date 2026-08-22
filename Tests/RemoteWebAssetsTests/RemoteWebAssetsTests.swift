import RemoteWebAssets
import RemoteWebAssetsAPI
import Testing

@Suite("Bundled remote reader")
struct RemoteWebAssetsTests {
    @Test("Only three local assets are exposed")
    func allowlist() {
        #expect(RemoteWebAssetCatalog.asset(for: "/") != nil)
        #expect(RemoteWebAssetCatalog.asset(for: "/reader.css") != nil)
        #expect(RemoteWebAssetCatalog.asset(for: "/reader.js") != nil)
        #expect(RemoteWebAssetCatalog.asset(for: "/private") == nil)
    }

    @Test("The client has no third-party fetches and includes reader safeguards")
    func clientBehavior() throws {
        let asset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.js"))
        let script = try #require(String(bytes: asset.body, encoding: .utf8))
        #expect(!script.contains("https://"))
        #expect(script.contains("Math.random() * ceiling"))
        #expect(script.contains("seen.add(`${sessionID}:${entry.id}:${entry.revision}`)"))
        #expect(script.contains("visibleAnchor"))
        #expect(script.contains("Jump to Live") == false)
    }
}
