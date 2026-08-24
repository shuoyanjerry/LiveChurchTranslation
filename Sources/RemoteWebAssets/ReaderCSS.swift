enum ReaderCSS {
    static let value = ReaderCSSLayout.value + ReaderCSSControls.value
}

private enum ReaderCSSLayout {
    static let value = #"""
        :root {
          color-scheme: light;
          --canvas: #f5f5f7;
          --paper: #fff;
          --ink: #1e2521;
          --muted: #65706a;
          --stone: #d7ded8;
          --olive: #66745a;
          --gold: #b9924b;
          --live: #3f6f50;
          --danger: #b8473a;
          --reader-size: 30px;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        * { box-sizing: border-box; }
        html, body { height: 100%; margin: 0; background: var(--canvas); color: var(--ink); }
        body { overflow: hidden; display: flex; flex-direction: column; }
        .topbar {
          min-height: 72px;
          flex: 0 0 auto;
          padding: max(12px, env(safe-area-inset-top)) max(20px, env(safe-area-inset-right)) 12px
            max(20px, env(safe-area-inset-left));
          display: flex;
          align-items: center;
          justify-content: space-between;
          border-bottom: 1px solid var(--stone);
          background: rgba(245, 245, 247, .94);
          backdrop-filter: blur(16px);
        }
        .brand { display: flex; align-items: center; min-width: 0; }
        .brand strong { font: 600 17px Georgia, serif; }
        .connection {
          flex: 0 1 auto;
          font-size: 13px;
          color: var(--muted);
          padding: 8px 12px;
          border: 1px solid var(--stone);
          border-radius: 999px;
          overflow-wrap: anywhere;
          text-align: center;
        }
        .connection.live { color: var(--live); border-color: #b8cbbb; }
        .connection.error { color: var(--danger); }
        main {
          flex: 1;
          min-height: 0;
          overflow-y: auto;
          overscroll-behavior: contain;
          padding: 28px max(18px, env(safe-area-inset-right))
            calc(96px + env(safe-area-inset-bottom)) max(18px, env(safe-area-inset-left));
          scroll-behavior: smooth;
        }
        .reader {
          max-width: 980px;
          min-height: 100%;
          margin: auto;
          background: var(--paper);
          border: 1px solid var(--stone);
          border-radius: 8px;
          padding: clamp(24px, 6vw, 72px);
          box-shadow: 0 14px 42px rgba(30, 37, 33, .06);
        }
        .reader-head {
          display: flex;
          justify-content: space-between;
          gap: 24px;
          padding-bottom: 24px;
          border-bottom: 1px solid var(--stone);
        }
        .eyebrow {
          margin: 0 0 8px;
          color: var(--olive);
          font-size: 11px;
          font-weight: 700;
          letter-spacing: .15em;
        }
        .reader h1 {
          font: 400 clamp(32px, 6vw, 56px) Georgia, serif;
          margin: 0;
          line-height: 1.05;
        }
        .text-tools { display: flex; align-items: flex-start; gap: 6px; }
        .text-tools button {
          min-width: 44px;
          height: 44px;
          border: 1px solid var(--stone);
          background: white;
          border-radius: 999px;
          color: var(--ink);
          font-weight: 600;
        }
        .empty { text-align: center; max-width: 480px; margin: 15vh auto; color: var(--muted); }
        .empty h2 { font: 400 28px Georgia, serif; color: var(--ink); margin: 20px 0 8px; }
        .transcript { font-family: Georgia, "Times New Roman", serif; }
        .entry { padding: 28px 0; border-bottom: 1px solid #e9edea; }
        .entry:last-child { border-bottom: 0; }
        .target {
          font-size: var(--reader-size);
          line-height: 1.5;
          margin: 0;
          letter-spacing: -.01em;
          overflow-wrap: anywhere;
        }
        .source {
          font: 400 14px/1.55 -apple-system, BlinkMacSystemFont, sans-serif;
          color: var(--muted);
          margin: 10px 0 0;
          overflow-wrap: anywhere;
        }
        .entry.latest { border-left: 3px solid var(--gold); padding-left: 18px; }
        """#
}

private enum ReaderCSSControls {
    static let value = #"""
        button { cursor: pointer; }
        .jump, .operator { position: fixed; bottom: calc(20px + env(safe-area-inset-bottom)); z-index: 5; }
        .jump {
          right: max(20px, env(safe-area-inset-right));
          height: 48px;
          padding: 0 18px;
          color: white;
          background: var(--ink);
          border: 0;
          border-radius: 999px;
          box-shadow: 0 8px 24px rgba(30, 37, 33, .2);
        }
        .operator {
          left: max(20px, env(safe-area-inset-left));
          display: flex;
          gap: 8px;
          padding: 6px;
          background: white;
          border: 1px solid var(--stone);
          border-radius: 999px;
        }
        .operator button {
          height: 40px;
          min-width: 76px;
          border: 0;
          border-radius: 999px;
          background: #edf2ee;
          color: var(--ink);
          font-weight: 700;
        }
        .operator #start { background: var(--ink); color: white; }
        .pairing {
          position: fixed;
          inset: auto 20px calc(20px + env(safe-area-inset-bottom));
          max-width: 460px;
          margin: auto;
          padding: 16px 20px;
          background: var(--ink);
          color: white;
          border-radius: 8px;
          z-index: 9;
        }
        [hidden] { display: none !important; }
        :focus-visible { outline: 3px solid #4e6e7d; outline-offset: 3px; }
        @media (max-width: 600px) {
          .topbar { min-height: 66px; }
          main { padding-top: 12px; }
          .reader { border-radius: 6px; padding: 24px 20px; }
          .reader-head { align-items: center; }
          .reader h1 { font-size: 34px; }
          .eyebrow { font-size: 9px; }
          .target { line-height: 1.42; }
        }
        @media (prefers-reduced-motion: reduce) { main { scroll-behavior: auto; } }
        """#
}
