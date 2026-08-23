enum ReaderJavaScriptPreamble {
    static let value = #"""
        (() => {
          "use strict";
          const main = document.querySelector("main");
          const transcript = document.querySelector("#transcript");
          const empty = document.querySelector("#empty");
          const connection = document.querySelector("#connection");
          const direction = document.querySelector("#direction");
          const jump = document.querySelector("#jump");
          const unseenLabel = document.querySelector("#unseen");
          const pairing = document.querySelector("#pairing");
          const operator = document.querySelector("#operator");
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
        """#
}
