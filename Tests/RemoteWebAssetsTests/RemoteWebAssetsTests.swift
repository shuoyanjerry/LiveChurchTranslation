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
        #expect(script.contains("target.lang = entry.targetLanguage"))
        #expect(script.contains("source.lang = entry.sourceLanguage"))
        #expect(script.contains("Jump to Live") == false)
        #expect(script.contains("中 → 英"))
        #expect(script.contains("英 → 中"))
        #expect(script.contains("正在重新连接"))
        #expect(script.contains("邀请无效或已过期"))
        #expect(script.contains("phaseLabels[phase]"))
        #expect(script.contains("phase === \"failed\" ? \"error\" : \"live\""))
        #expect(script.contains("command: \"stop\""))
    }

    @Test("The reader shell defaults to Simplified Chinese")
    func simplifiedChineseShell() throws {
        let asset = try #require(RemoteWebAssetCatalog.asset(for: "/"))
        let html = try #require(String(bytes: asset.body, encoding: .utf8))

        #expect(html.contains("<html lang=\"zh-CN\">"))
        #expect(html.contains("<title>教会实时翻译</title>"))
        #expect(html.contains("<strong>教会实时翻译</strong>"))
        #expect(html.contains("正在连接"))
        #expect(html.contains("id=\"direction\""))
        #expect(html.contains("等待讲员开始"))
        #expect(html.contains("回到最新"))
        #expect(!html.contains("THE CHURCH IN NORTHVILLE"))
    }
}
