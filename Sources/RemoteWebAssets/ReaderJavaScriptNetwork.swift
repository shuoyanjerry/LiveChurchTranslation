enum ReaderJavaScriptNetwork {
    static let value = #"""
          const fetchSnapshot = async () => {
            const response = await fetch("/api/snapshot", {cache: "no-store"});
            if (!response.ok) throw readerFailure("cannotJoin");
            applySnapshot(await response.json());
          };
          const connect = () => {
            const scheme = location.protocol === "https:" ? "wss" : "ws";
            socket = new WebSocket(`${scheme}://${location.host}/ws`);
            socket.onopen = () => {
              retry = 0;
              heartbeatAt = Date.now();
              connectedAt = Date.now();
              setConnectionKey("connected");
              schedulePhasePresentation();
            };
            socket.onmessage = event => {
              try {
                applyEnvelope(JSON.parse(event.data));
              } catch {
                fetchSnapshot().catch(() => setConnectionKey("reconnecting"));
              }
            };
            socket.onerror = () => socket.close();
            socket.onclose = () => {
              clearTimeout(phasePresentationTimer);
              setConnectionKey("reconnecting");
              const ceiling = Math.min(30000, 500 * (2 ** Math.min(retry++, 6)));
              setTimeout(connect, Math.random() * ceiling);
            };
          };
          const redeemFragment = async () => {
            const pattern = /^#invite=([0-9a-f-]{36})\.([A-Za-z0-9_-]{43})$/i;
            const match = location.hash.match(pattern);
            if (!match) return;
            history.replaceState(null, "", location.pathname + location.search);
            const body = {
              invitationID: match[1],
              fragmentCredential: match[2],
              peerMetadata: {
                displayName: navigator.platform || copy.deviceName,
                userAgentSummary: navigator.userAgent.slice(0, 160)
              }
            };
            const response = await fetch("/api/pair", {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify(body)
            });
            if (response.status === 429) {
              throw readerFailure("roomFull");
            }
            if (!response.ok) {
              throw readerFailure("cannotJoin");
            }
            pairing.textContent = "";
            pairing.hidden = true;
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
          timestamps.onclick = () => {
            showTimestamps = !showTimestamps;
            localStorage.setItem("readerTimestamps", String(showTimestamps));
            applyTimestampPreference();
          };
          smaller.onclick = () => setSize(fontSize - 2);
          larger.onclick = () => setSize(fontSize + 2);
          setInterval(() => {
            if (socket?.readyState !== WebSocket.OPEN) return;
            if (Date.now() - heartbeatAt > 30000) socket.close();
            else socket.send(JSON.stringify({type: "ping"}));
          }, 10000);
          setSize(fontSize);
          applyTimestampPreference();
          redeemFragment()
            .then(fetchSnapshot)
            .then(connect)
            .catch(error => {
              pairing.textContent = failureText(error);
              pairing.hidden = false;
              setConnectionKey("cannotJoin", "error");
            });
        })();
        """#
}
