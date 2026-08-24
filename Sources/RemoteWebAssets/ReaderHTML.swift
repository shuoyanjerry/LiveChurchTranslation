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
            <div id="connection" class="connection busy" role="status">正在连接</div>
          </header>
          <main>
            <section id="reader" class="reader" aria-label="聚会实时听抄与翻译">
              <div class="reader-head">
                <div>
                  <p id="direction" class="eyebrow" role="status">等待开始</p>
                  <h1 id="reader-title">聚会信息</h1>
                </div>
                <div id="text-tools" class="text-tools" aria-label="调整阅读显示">
                  <button id="timestamps" type="button" aria-label="段落时间" aria-pressed="true">
                    <span id="timestamp-toggle-label">时间</span>
                  </button>
                  <button id="smaller" type="button" aria-label="减小字幕字号">A−</button>
                  <button id="larger" type="button" aria-label="增大字幕字号">A+</button>
                </div>
              </div>
              <div id="empty" class="empty">
                <h2 id="empty-title">等待讲员开始</h2>
                <p id="empty-body">字幕将在这里显示。</p>
              </div>
              <div id="transcript" class="transcript" aria-label="实时字幕" aria-live="polite"></div>
            </section>
          </main>
          <button id="jump" class="jump" type="button" hidden>
            <span id="jump-label">回到最新</span> <span id="unseen"></span>
          </button>
          <div id="pairing" class="pairing" role="alert" hidden></div>
        </body>
        </html>
        """#
}
