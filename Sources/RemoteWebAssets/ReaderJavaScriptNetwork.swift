enum ReaderJavaScriptNetwork {
    static let value = #"""
          const fetchSnapshot = async () => {
            const response = await fetch("/api/snapshot", {cache: "no-store"});
            if (!response.ok) throw new Error("Snapshot unavailable");
            applySnapshot(await response.json());
            const role = response.headers.get("X-Remote-Role");
            operator.hidden = role !== "operator";
          };
          const connect = () => {
            const scheme = location.protocol === "https:" ? "wss" : "ws";
            socket = new WebSocket(`${scheme}://${location.host}/ws`);
            socket.onopen = () => {
              retry = 0;
              heartbeatAt = Date.now();
              setConnection("Connected", "live");
            };
            socket.onmessage = event => {
              try {
                applyEnvelope(JSON.parse(event.data));
              } catch {
                fetchSnapshot();
              }
            };
            socket.onerror = () => socket.close();
            socket.onclose = () => {
              setConnection("Reconnecting");
              const ceiling = Math.min(30000, 500 * (2 ** Math.min(retry++, 6)));
              setTimeout(connect, Math.random() * ceiling);
            };
          };
          const redeemFragment = async () => {
            const pattern = /^#invite=([0-9a-f-]{36})\.([A-Za-z0-9_-]{43})$/i;
            const match = location.hash.match(pattern);
            if (!match) return;
            history.replaceState(null, "", location.pathname);
            const body = {
              invitationID: match[1],
              fragmentCredential: match[2],
              peerMetadata: {
                displayName: navigator.platform || "Safari device",
                userAgentSummary: navigator.userAgent.slice(0, 160)
              }
            };
            const response = await fetch("/api/pair", {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify(body)
            });
            if (!response.ok) {
              throw new Error("Pairing invitation is invalid or expired");
            }
          };
          const control = async command => {
            const response = await fetch("/api/control", {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify({
                requestID: crypto.randomUUID(),
                command,
                expectedRevision: revision
              })
            });
            if (!response.ok) {
              pairing.textContent = "The Mac did not accept this request. Refreshing live state.";
              pairing.hidden = false;
            }
            await fetchSnapshot();
          };
          const setSize = size => {
            fontSize = Math.max(20, Math.min(56, size));
            document.documentElement.style.setProperty("--reader-size", `${fontSize}px`);
            localStorage.setItem("readerSize", fontSize);
          };
          main.addEventListener("scroll", () => {
            following = nearBottom();
            if (following) unseen = 0;
            updateJump();
          }, {passive: true});
          jump.addEventListener("click", scrollLive);
          document.querySelector("#smaller").onclick = () => setSize(fontSize - 2);
          document.querySelector("#larger").onclick = () => setSize(fontSize + 2);
          document.querySelector("#start").onclick = () => control("start");
          document.querySelector("#stop").onclick = () => control("stop");
          setInterval(() => {
            if (socket?.readyState !== WebSocket.OPEN) return;
            if (Date.now() - heartbeatAt > 30000) socket.close();
            else socket.send(JSON.stringify({type: "ping"}));
          }, 10000);
          setSize(fontSize);
          redeemFragment()
            .then(fetchSnapshot)
            .then(connect)
            .catch(error => {
              pairing.textContent = error.message;
              pairing.hidden = false;
              setConnection("Not paired", "error");
            });
        })();
        """#
}
