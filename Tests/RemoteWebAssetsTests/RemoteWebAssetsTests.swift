import Foundation
import JavaScriptCore
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
        #expect(script.contains("当前无法加入"))
        #expect(script.contains("连接人数已满"))
        #expect(script.contains("正在聆听"))
        #expect(script.contains("正在识别"))
        #expect(script.contains("正在翻译"))
        #expect(script.contains("Listening"))
        #expect(script.contains("Recognizing"))
        #expect(script.contains("Translating"))
        let credentialRead = try #require(script.range(of: "const match = location.hash.match"))
        let credentialRemoval = try #require(script.range(of: "history.replaceState"))
        let pairingRequest = try #require(script.range(of: "fetch(\"/api/pair\""))
        #expect(credentialRead.lowerBound < credentialRemoval.lowerBound)
        #expect(credentialRemoval.lowerBound < pairingRequest.lowerBound)
        #expect(script.contains("copy.phaseLabels[presentation.value]"))
        #expect(script.contains("phaseConnectionState"))
        #expect(script.contains("phase === \"listening\""))
        #expect(script.contains("minimumConnectedMilliseconds"))
        #expect(script.contains("pendingSessionPhase = phase"))
        #expect(script.contains("setConnectionKey(\"connected\");"))
        #expect(script.contains("schedulePhasePresentation();"))
        #expect(!script.contains("snapshot.statusMessage"))
        #expect(!script.contains("payload.message"))
        #expect(!script.contains("error.message"))
    }

    @Test("The reader timestamps entries and remembers the visibility preference")
    func timestamps() throws {
        let htmlAsset = try #require(RemoteWebAssetCatalog.asset(for: "/"))
        let scriptAsset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.js"))
        let styleAsset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.css"))
        let html = try #require(String(bytes: htmlAsset.body, encoding: .utf8))
        let script = try #require(String(bytes: scriptAsset.body, encoding: .utf8))
        let style = try #require(String(bytes: styleAsset.body, encoding: .utf8))

        #expect(html.contains("id=\"timestamps\""))
        #expect(html.contains("aria-pressed=\"true\""))
        #expect(script.contains("entry.startedMilliseconds"))
        #expect(script.contains("readerTimestamps"))
        #expect(script.contains("hide-timestamps"))
        #expect(style.contains(".timestamp"))
        #expect(style.contains("prefers-reduced-motion"))
    }

    @Test("The bundled reader script is valid JavaScript")
    func javascriptSyntax() throws {
        let asset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.js"))
        let script = try #require(String(bytes: asset.body, encoding: .utf8))
        let context = try #require(JSContext())
        context.setObject(script, forKeyedSubscript: "readerScript" as NSString)

        _ = context.evaluateScript("new Function(readerScript)")

        #expect(context.exception?.toString() == nil)
    }

    @Test("The target language localizes all reader chrome before entries arrive")
    func targetLanguageChrome() throws {
        let asset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.js"))
        let script = try #require(String(bytes: asset.body, encoding: .utf8))

        #expect(script.contains("snapshot.sourceLanguage"))
        #expect(script.contains("snapshot.targetLanguage"))
        #expect(script.contains("setDirection(payload.sourceLanguage, payload.targetLanguage)"))
        #expect(script.contains("document.documentElement.lang = copy.htmlLanguage"))
        #expect(script.contains("htmlLanguage: \"en\""))
        #expect(script.contains("htmlLanguage: \"zh-CN\""))
        #expect(script.contains("Meeting Translation"))
        #expect(script.contains("Waiting for the speaker"))
        #expect(script.contains("Back to latest"))
        #expect(script.contains("聚会信息"))
        #expect(script.contains("等待讲员开始"))
        #expect(script.contains("回到最新"))
    }

    @Test("The production reader is read-only")
    func readerIsReadOnly() throws {
        let htmlAsset = try #require(RemoteWebAssetCatalog.asset(for: "/"))
        let scriptAsset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.js"))
        let styleAsset = try #require(RemoteWebAssetCatalog.asset(for: "/reader.css"))
        let html = try #require(String(bytes: htmlAsset.body, encoding: .utf8))
        let script = try #require(String(bytes: scriptAsset.body, encoding: .utf8))
        let style = try #require(String(bytes: styleAsset.body, encoding: .utf8))

        #expect(!html.contains("id=\"operator\""))
        #expect(!html.contains("id=\"stop\""))
        #expect(!script.contains("/api/control"))
        #expect(!script.contains("command: \"stop\""))
        #expect(!script.contains("X-Remote-Role"))
        #expect(!style.contains(".operator"))
    }

    @Test("The reader shell defaults to Simplified Chinese")
    func simplifiedChineseShell() throws {
        let asset = try #require(RemoteWebAssetCatalog.asset(for: "/"))
        let html = try #require(String(bytes: asset.body, encoding: .utf8))

        #expect(html.contains("<html lang=\"zh-CN\">"))
        #expect(html.contains("<title>Live Church Translation</title>"))
        #expect(html.contains("<strong>Live Church Translation</strong>"))
        #expect(html.contains("正在连接"))
        #expect(html.contains("id=\"direction\""))
        #expect(html.contains("等待讲员开始"))
        #expect(html.contains("回到最新"))
        #expect(!html.contains("THE CHURCH IN NORTHVILLE"))
    }
}
