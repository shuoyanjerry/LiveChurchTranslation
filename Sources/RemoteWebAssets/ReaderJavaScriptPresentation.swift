enum ReaderJavaScriptPresentation {
    static let value = #"""
          const phaseLabels = Object.freeze({
            idle: "等待开始",
            preparing: "准备中",
            listening: "直播中",
            recognizing: "直播中",
            translating: "直播中",
            stopping: "即将结束",
            failed: "已暂停"
          });

          const setConnection = (label, state = "") => {
            connection.textContent = label;
            connection.className = `connection ${state}`;
          };
          const connectionLabel = (message, phase) =>
            phaseLabels[phase] || message || "正在同步";
          const connectionState = phase => phase === "failed" ? "error" : "live";
          const baseLanguage = value => String(value || "").toLowerCase().split("-")[0];
          const setDirection = (sourceLanguage, targetLanguage) => {
            const source = baseLanguage(sourceLanguage);
            const target = baseLanguage(targetLanguage);
            if (source === "zh" && target === "en") {
              direction.textContent = "中 → 英";
              direction.setAttribute("aria-label", "翻译方向：中文到英文");
            } else if (source === "en" && target === "zh") {
              direction.textContent = "英 → 中";
              direction.setAttribute("aria-label", "翻译方向：英文到中文");
            } else {
              direction.textContent = "等待开始";
              direction.removeAttribute("aria-label");
            }
          };
          const setDirectionFromEntries = values => {
            const entry = [...values].reverse().find(
              value => value.sourceLanguage && value.targetLanguage
            );
            setDirection(entry?.sourceLanguage, entry?.targetLanguage);
          };
        """#
}
