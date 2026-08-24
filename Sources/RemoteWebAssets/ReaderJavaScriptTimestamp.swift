enum ReaderJavaScriptTimestamp {
    static let value = #"""
          const formatTimestamp = milliseconds => {
            if (typeof milliseconds !== "number" || !Number.isFinite(milliseconds)) return "";
            const totalSeconds = Math.max(0, Math.floor(milliseconds / 1000));
            const hours = Math.floor(totalSeconds / 3600);
            const minutes = Math.floor((totalSeconds % 3600) / 60);
            const seconds = totalSeconds % 60;
            return [hours, minutes, seconds]
              .map(value => String(value).padStart(2, "0"))
              .join(":");
          };
          const applyTimestampPreference = () => {
            reader.classList.toggle("hide-timestamps", !showTimestamps);
            timestamps.setAttribute("aria-pressed", String(showTimestamps));
          };
        """#
}
