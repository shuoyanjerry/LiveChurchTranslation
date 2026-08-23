enum ReaderJavaScriptPresentation {
    static let value = #"""
          const phaseLabels = Object.freeze({
            idle: "等待 Mac 开始",
            preparing: "正在准备本机模型",
            listening: "正在聆听",
            recognizing: "正在识别语音",
            translating: "正在翻译",
            stopping: "正在完成当前语句",
            failed: "请在 Mac 上检查"
          });

          const setConnection = (label, state = "") => {
            connection.textContent = label;
            connection.className = `connection ${state}`;
          };
          const connectionLabel = (message, phase) =>
            message || phaseLabels[phase] || "正在同步状态";
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
              direction.textContent = "翻译方向同步中";
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
