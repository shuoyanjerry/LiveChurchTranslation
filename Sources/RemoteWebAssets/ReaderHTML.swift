enum ReaderHTML {
    static let value = #"""
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
          <meta name="theme-color" content="#f5f5f7">
          <title>Live Church Translation</title>
          <link rel="stylesheet" href="/reader.css">
          <script defer src="/reader.js"></script>
        </head>
        <body>
          <header class="topbar">
            <div class="brand">
              <strong>Live Church Translation</strong>
            </div>
            <div id="connection" class="connection" role="status">正在连接</div>
          </header>
          <main>
            <section class="reader" aria-label="聚会实时听抄与翻译">
              <div class="reader-head">
                <div><p id="direction" class="eyebrow" role="status">等待开始</p><h1>聚会信息</h1></div>
                <div class="text-tools" aria-label="调整字幕字号">
                  <button id="smaller" type="button" aria-label="减小字幕字号">A−</button>
                  <button id="larger" type="button" aria-label="增大字幕字号">A+</button>
                </div>
              </div>
              <div id="empty" class="empty">
                <h2>等待讲员开始</h2>
                <p>字幕将在这里显示。</p>
              </div>
              <div id="transcript" class="transcript" aria-label="实时字幕" aria-live="polite"></div>
            </section>
          </main>
          <div id="operator" class="operator" hidden>
            <button id="stop" type="button">在 Mac 上结束</button>
          </div>
          <button id="jump" class="jump" type="button" hidden>回到最新 <span id="unseen"></span></button>
          <div id="pairing" class="pairing" role="alert" hidden></div>
        </body>
        </html>
        """#
}
