enum ReaderJavaScriptPresentation {
    static let value = #"""
          const baseLanguage = value => String(value || "").toLowerCase().split("-")[0];
          const renderConnection = () => {
            const presentation = connectionPresentation;
            connection.textContent = presentation.kind === "phase"
              ? copy.phaseLabels[presentation.value] || copy.syncing
              : copy[presentation.value] || copy.syncing;
            connection.className = `connection ${presentation.state}`;
          };
          const phaseConnectionState = phase => {
            if (phase === "failed") return "error";
            if (phase === "listening") return "active";
            if (["preparing", "recognizing", "translating", "stopping"].includes(phase)) {
              return "busy";
            }
            return "";
          };
          const connectionKeyState = key => {
            if (["connecting", "reconnecting", "syncing"].includes(key)) return "busy";
            if (["cannotJoin", "roomFull"].includes(key)) return "error";
            return key === "connected" ? "live" : "";
          };
          const setConnectionKey = (key, state = connectionKeyState(key)) => {
            connectionPresentation = {kind: "key", value: key, state};
            renderConnection();
          };
          const minimumConnectedMilliseconds = 700;
          const presentPendingSessionPhase = () => {
            phasePresentationTimer = undefined;
            if (!pendingSessionPhase || socket?.readyState !== WebSocket.OPEN) return;
            connectionPresentation = {
              kind: "phase",
              value: pendingSessionPhase,
              state: phaseConnectionState(pendingSessionPhase)
            };
            renderConnection();
          };
          const schedulePhasePresentation = () => {
            if (socket?.readyState !== WebSocket.OPEN) return;
            clearTimeout(phasePresentationTimer);
            const remaining = Math.max(
              0,
              minimumConnectedMilliseconds - (Date.now() - connectedAt)
            );
            phasePresentationTimer = setTimeout(presentPendingSessionPhase, remaining);
          };
          const setConnectionPhase = phase => {
            pendingSessionPhase = phase;
            schedulePhasePresentation();
          };
          const applyChromeLanguage = targetLanguage => {
            copy = baseLanguage(targetLanguage) === "en"
              ? copyByTargetLanguage.en
              : copyByTargetLanguage.zh;
            document.documentElement.lang = copy.htmlLanguage;
            reader.setAttribute("aria-label", copy.readerLabel);
            readerTitle.textContent = copy.readerTitle;
            textTools.setAttribute("aria-label", copy.textToolsLabel);
            timestamps.setAttribute("aria-label", copy.timestampsLabel);
            timestampToggleLabel.textContent = copy.timestampToggleLabel;
            smaller.setAttribute("aria-label", copy.smallerLabel);
            larger.setAttribute("aria-label", copy.largerLabel);
            emptyTitle.textContent = copy.emptyTitle;
            emptyBody.textContent = copy.emptyBody;
            transcript.setAttribute("aria-label", copy.transcriptLabel);
            jumpLabel.textContent = copy.jumpLabel;
            unseenLabel.textContent = unseen ? copy.newEntries(unseen) : "";
            renderConnection();
          };
          const setDirection = (sourceLanguage, targetLanguage) => {
            const source = baseLanguage(sourceLanguage);
            const target = baseLanguage(targetLanguage);
            applyChromeLanguage(targetLanguage);
            if (source === "zh" && target === "en") {
              direction.textContent = copy.mandarinToEnglish;
              direction.setAttribute("aria-label", copy.mandarinToEnglishLabel);
            } else if (source === "en" && target === "zh") {
              direction.textContent = copy.englishToMandarin;
              direction.setAttribute("aria-label", copy.englishToMandarinLabel);
            } else {
              direction.textContent = copy.waitingDirection;
              direction.removeAttribute("aria-label");
            }
          };
          const setDirectionFromSnapshot = snapshot => {
            const values = snapshot.entries || [];
            const entry = [...values].reverse().find(
              value => value.sourceLanguage && value.targetLanguage
            );
            setDirection(
              snapshot.sourceLanguage || entry?.sourceLanguage,
              snapshot.targetLanguage || entry?.targetLanguage
            );
          };
          const readerFailure = copyKey => Object.assign(new Error(copyKey), {copyKey});
          const failureText = failure => copy[failure?.copyKey] || copy.cannotJoin;
        """#
}
