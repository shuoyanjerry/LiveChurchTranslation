enum ReaderHTML {
    static let value = #"""
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
          <meta name="theme-color" content="#f5f5f7">
          <title>Quiet Liturgy Reader</title>
          <link rel="stylesheet" href="/reader.css">
          <script defer src="/reader.js"></script>
        </head>
        <body>
          <header class="topbar">
            <div class="brand">
              <span><strong>Quiet Liturgy</strong><small>Live English translation</small></span>
            </div>
            <div id="connection" class="connection" role="status">Connecting</div>
          </header>
          <main>
            <section class="reader" aria-label="Live sermon transcript">
              <div class="reader-head">
                <div><p class="eyebrow">THE CHURCH IN NORTHVILLE</p><h1>Sunday Message</h1></div>
                <div class="text-tools" aria-label="Text size">
                  <button id="smaller" type="button" aria-label="Decrease text size">A−</button>
                  <button id="larger" type="button" aria-label="Increase text size">A+</button>
                </div>
              </div>
              <div id="empty" class="empty">
                <h2>Waiting for the message</h2>
                <p>The English translation will appear here as the speaker continues.</p>
              </div>
              <div id="transcript" class="transcript" aria-live="polite"></div>
            </section>
          </main>
          <div id="operator" class="operator" hidden>
            <button id="start" type="button">Start</button><button id="stop" type="button">Stop</button>
          </div>
          <button id="jump" class="jump" type="button" hidden>Jump to Live <span id="unseen"></span></button>
          <div id="pairing" class="pairing" role="alert" hidden></div>
        </body>
        </html>
        """#
}
