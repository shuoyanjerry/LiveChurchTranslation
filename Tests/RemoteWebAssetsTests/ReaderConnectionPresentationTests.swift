import Foundation
import JavaScriptCore
@testable import RemoteWebAssets
import Testing

@Suite("Remote reader connection presentation")
struct ReaderConnectionPresentationTests {
    @Test("Connection phases remain ordered and timestamps stay independent")
    func orderedConnectionPresentation() throws {
        let context = try #require(JSContext())
        let closingRange = try #require(
            ReaderJavaScriptNetwork.value.range(of: "})();", options: .backwards)
        )
        let network =
            String(ReaderJavaScriptNetwork.value[..<closingRange.lowerBound])
            + testScenario
        let script =
            mockBrowserEnvironment
            + ReaderJavaScriptPreamble.value
            + ReaderJavaScriptCopy.value
            + ReaderJavaScriptPresentation.value
            + ReaderJavaScriptTimestamp.value
            + networkDependencies
            + network

        _ = context.evaluateScript(script)

        #expect(context.exception?.toString() == nil)
        #expect(string("__initialConnection", in: context) == "正在连接")
        #expect(string("__beforeOpen", in: context) == "正在连接")
        #expect(string("__connected", in: context) == "已连接")
        #expect(number("__connectedDwell", in: context) == 700)
        #expect(string("__listening", in: context) == "正在聆听")
        #expect(string("__englishListening", in: context) == "Listening")
        #expect(string("__reconnecting", in: context) == "Reconnecting")
        #expect(string("__timestampsPressed", in: context) == "false")
        #expect(boolean("__timestampsHidden", in: context))
    }
}

private func string(_ key: String, in context: JSContext) -> String? {
    context.objectForKeyedSubscript(key)?.toString()
}

private func number(_ key: String, in context: JSContext) -> Int32 {
    context.objectForKeyedSubscript(key)?.toInt32() ?? -1
}

private func boolean(_ key: String, in context: JSContext) -> Bool {
    context.objectForKeyedSubscript(key)?.toBool() ?? false
}

private let mockBrowserEnvironment = #"""
    globalThis.__now = 1000;
    Date.now = () => globalThis.__now;
    class MockWebSocket {
      static CONNECTING = 0;
      static OPEN = 1;
      constructor() { this.readyState = MockWebSocket.CONNECTING; }
      send() {}
      close() {
        this.readyState = 3;
        if (this.onclose) this.onclose();
      }
    }
    globalThis.WebSocket = MockWebSocket;
    globalThis.__timers = [];
    globalThis.setTimeout = (callback, delay) => {
      const timer = {callback, delay, cancelled: false};
      globalThis.__timers.push(timer);
      return timer;
    };
    globalThis.clearTimeout = timer => {
      if (timer) timer.cancelled = true;
    };
    globalThis.setInterval = () => 1;
    globalThis.requestAnimationFrame = callback => callback();
    globalThis.location = {
      protocol: "http:",
      host: "127.0.0.1:8080",
      hash: "",
      pathname: "/",
      search: ""
    };
    globalThis.history = {replaceState() {}};
    globalThis.navigator = {platform: "Safari", userAgent: "Safari QA"};
    globalThis.fetch = async () => ({ok: true, status: 200, json: async () => ({})});
    const makeElement = () => {
      const attributes = new Map();
      const classes = new Set();
      return {
        textContent: "",
        className: "",
        hidden: false,
        style: {setProperty() {}},
        classList: {
          toggle(name, force) {
            if (force) classes.add(name);
            else classes.delete(name);
          },
          contains(name) { return classes.has(name); }
        },
        setAttribute(name, value) { attributes.set(name, String(value)); },
        getAttribute(name) { return attributes.get(name) || null; },
        removeAttribute(name) { attributes.delete(name); },
        addEventListener() {},
        append() {},
        appendChild() {},
        replaceChildren() {}
      };
    };
    globalThis.__elements = new Map();
    globalThis.document = {
      documentElement: makeElement(),
      querySelector(selector) {
        if (!globalThis.__elements.has(selector)) {
          globalThis.__elements.set(selector, makeElement());
        }
        return globalThis.__elements.get(selector);
      }
    };
    globalThis.localStorage = {
      getItem() { return null; },
      setItem() {}
    };
    """#

private let networkDependencies = #"""
      const nearBottom = () => true;
      const scrollLive = () => {};
      const applySnapshot = snapshot => setConnectionPhase(snapshot.phase);
      const applyEnvelope = () => {};
    """#

private let testScenario = #"""
      renderConnection();
      globalThis.__initialConnection = connection.textContent;

      setConnectionPhase("listening");
      globalThis.__beforeOpen = connection.textContent;

      connect();
      socket.readyState = WebSocket.OPEN;
      socket.onopen();
      globalThis.__connected = connection.textContent;
      const timer = globalThis.__timers.find(value => !value.cancelled);
      globalThis.__connectedDwell = timer.delay;

      globalThis.__now += timer.delay;
      timer.callback();
      globalThis.__listening = connection.textContent;

      applyChromeLanguage("en");
      globalThis.__englishListening = connection.textContent;
      socket.readyState = 3;
      socket.onclose();
      globalThis.__reconnecting = connection.textContent;

      timestamps.onclick();
      globalThis.__timestampsPressed = timestamps.getAttribute("aria-pressed");
      globalThis.__timestampsHidden = reader.classList.contains("hide-timestamps");
    })();
    """#
