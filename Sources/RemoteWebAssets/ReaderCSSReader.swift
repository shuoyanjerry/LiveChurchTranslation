enum ReaderCSSReader {
    static let value = #"""
        .transcript { font-family: Georgia, "Times New Roman", serif; }
        .entry {
          display: grid;
          grid-template-columns: 70px minmax(0, 1fr);
          align-items: start;
          gap: 22px;
          padding: 28px 0;
          border-bottom: 1px solid #e9edea;
        }
        .entry:last-child { border-bottom: 0; }
        .timestamp {
          padding-top: .68em;
          color: var(--muted);
          font: 400 12px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
          text-align: right;
          font-variant-numeric: tabular-nums;
        }
        .entry-copy { min-width: 0; }
        .reader.hide-timestamps .entry { grid-template-columns: minmax(0, 1fr); gap: 0; }
        .reader.hide-timestamps .timestamp { display: none; }
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
