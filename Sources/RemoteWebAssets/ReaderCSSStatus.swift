enum ReaderCSSStatus {
    static let value = #"""
        .connection {
          flex: 0 1 auto;
          display: inline-flex;
          align-items: center;
          gap: 7px;
          font-size: 13px;
          color: var(--muted);
          padding: 8px 12px;
          border: 1px solid var(--stone);
          border-radius: 999px;
          overflow-wrap: anywhere;
          text-align: center;
        }
        .connection::before {
          content: "";
          width: 7px;
          height: 7px;
          flex: 0 0 auto;
          border-radius: 999px;
          background: currentColor;
          opacity: .62;
        }
        .connection.live, .connection.active {
          color: var(--live);
          border-color: #b8cbbb;
        }
        .connection.busy { color: var(--olive); border-color: #c8d0c3; }
        .connection.busy::before {
          width: 8px;
          height: 8px;
          border: 1.5px solid currentColor;
          border-right-color: transparent;
          background: transparent;
          animation: status-spin 1.15s linear infinite;
        }
        .connection.active::before { animation: status-pulse 1.7s ease-in-out infinite; }
        .connection.error { color: var(--danger); }
        @keyframes status-spin { to { transform: rotate(360deg); } }
        @keyframes status-pulse {
          0%, 100% { opacity: .45; transform: scale(.82); }
          50% { opacity: 1; transform: scale(1); }
        }
        @media (prefers-reduced-motion: reduce) {
          .connection.busy::before, .connection.active::before { animation: none; }
        }
        """#
}
