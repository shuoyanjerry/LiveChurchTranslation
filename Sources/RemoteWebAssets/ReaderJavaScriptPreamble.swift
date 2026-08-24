enum ReaderJavaScriptPreamble {
    static let value = #"""
        (() => {
          "use strict";
          const main = document.querySelector("main");
          const transcript = document.querySelector("#transcript");
          const reader = document.querySelector("#reader");
          const readerTitle = document.querySelector("#reader-title");
          const textTools = document.querySelector("#text-tools");
          const timestamps = document.querySelector("#timestamps");
          const timestampToggleLabel = document.querySelector("#timestamp-toggle-label");
          const smaller = document.querySelector("#smaller");
          const larger = document.querySelector("#larger");
          const empty = document.querySelector("#empty");
          const emptyTitle = document.querySelector("#empty-title");
          const emptyBody = document.querySelector("#empty-body");
          const connection = document.querySelector("#connection");
          const direction = document.querySelector("#direction");
          const jump = document.querySelector("#jump");
          const jumpLabel = document.querySelector("#jump-label");
          const unseenLabel = document.querySelector("#unseen");
          const pairing = document.querySelector("#pairing");
          const entries = new Map();
          const seen = new Set();
          let socket;
          let retry = 0;
          let heartbeatAt = Date.now();
          let revision = 0;
          let sessionID = null;
          let following = true;
          let unseen = 0;
          let fontSize = Number(localStorage.getItem("readerSize") || 30);
          let showTimestamps = localStorage.getItem("readerTimestamps") !== "false";
          let connectionPresentation = {kind: "key", value: "connecting", state: "busy"};
          let pendingSessionPhase = null;
          let connectedAt = 0;
          let phasePresentationTimer;
        """#
}
