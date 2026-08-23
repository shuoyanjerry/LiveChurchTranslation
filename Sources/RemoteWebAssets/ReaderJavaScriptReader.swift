enum ReaderJavaScriptReader {
    static let value = #"""
          const nearBottom = () => main.scrollHeight - main.scrollTop - main.clientHeight < 100;
          const visibleAnchor = () => [...transcript.children].find(
            node => node.getBoundingClientRect().bottom > 80
          );
          const updateJump = () => {
            jump.hidden = following;
            unseenLabel.textContent = unseen ? `· ${unseen} 条新内容` : "";
          };
          const scrollLive = () => {
            main.scrollTop = main.scrollHeight;
            following = true;
            unseen = 0;
            updateJump();
          };
          const entryOrder = (a, b) => a.sequence - b.sequence
            || a.createdAt.localeCompare(b.createdAt)
            || a.id.localeCompare(b.id);
          const makeEntry = (entry, isLatest) => {
            const article = document.createElement("article");
            article.className = `entry ${isLatest ? "latest" : ""}`;
            article.dataset.id = entry.id;
            const target = document.createElement("p");
            target.className = "target";
            target.textContent = entry.targetText;
            if (entry.targetLanguage) target.lang = entry.targetLanguage;
            const source = document.createElement("p");
            source.className = "source";
            source.textContent = entry.sourceText;
            if (entry.sourceLanguage) source.lang = entry.sourceLanguage;
            article.append(target, source);
            return article;
          };
          const render = () => {
            const anchor = following ? null : visibleAnchor();
            const anchorTop = anchor?.getBoundingClientRect().top;
            const ordered = [...entries.values()].sort(entryOrder);
            const fragment = document.createDocumentFragment();
            ordered.forEach((entry, index) => {
              fragment.append(makeEntry(entry, index === ordered.length - 1));
            });
            transcript.replaceChildren(fragment);
            empty.hidden = ordered.length > 0;
            if (following) requestAnimationFrame(scrollLive);
            else if (anchor) {
              const replacement = [...transcript.children].find(
                node => node.dataset.id === anchor.dataset.id
              );
              if (replacement) {
                main.scrollTop += replacement.getBoundingClientRect().top - anchorTop;
              }
            }
          };
          const applySnapshot = snapshot => {
            revision = snapshot.revision;
            sessionID = snapshot.sessionID;
            entries.clear();
            seen.clear();
            snapshot.entries.forEach(entry => {
              entries.set(entry.id, entry);
              seen.add(`${sessionID}:${entry.id}:${entry.revision}`);
            });
            setDirectionFromEntries(snapshot.entries);
            render();
            setConnection(
              connectionLabel(snapshot.statusMessage, snapshot.phase),
              connectionState(snapshot.phase)
            );
          };
          const applyEnvelope = envelope => {
            const payload = envelope.payload;
            heartbeatAt = Date.now();
            if (payload.type === "snapshot") return applySnapshot(payload.snapshot);
            if (payload.type === "resyncRequired") return fetchSnapshot();
            if (payload.type === "heartbeat") return;
            revision = Math.max(revision, payload.revision || 0);
            if (payload.type === "stateChanged") {
              if (payload.sessionID && payload.sessionID !== sessionID) {
                sessionID = payload.sessionID;
                entries.clear();
                seen.clear();
                setDirection(null, null);
                render();
              }
              setConnection(
                connectionLabel(payload.message, payload.phase),
                connectionState(payload.phase)
              );
            }
            if (payload.type === "entryUpsert") {
              const key = `${payload.sessionID}:${payload.entry.id}:${payload.entry.revision}`;
              if (seen.has(key)) return;
              seen.add(key);
              sessionID = payload.sessionID;
              entries.set(payload.entry.id, payload.entry);
              if (payload.entry.sourceLanguage && payload.entry.targetLanguage) {
                setDirection(payload.entry.sourceLanguage, payload.entry.targetLanguage);
              }
              if (!following) unseen += 1;
              render();
              updateJump();
            }
          };
        """#
}
