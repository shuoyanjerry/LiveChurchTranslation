enum ReaderJavaScriptCopy {
    static let value = #"""
          const copyByTargetLanguage = Object.freeze({
            zh: Object.freeze({
              htmlLanguage: "zh-CN",
              readerLabel: "聚会实时听抄与翻译",
              readerTitle: "聚会信息",
              textToolsLabel: "调整阅读显示",
              timestampsLabel: "段落时间",
              timestampToggleLabel: "时间",
              timestampA11y: "时间点",
              smallerLabel: "减小字幕字号",
              largerLabel: "增大字幕字号",
              emptyTitle: "等待讲员开始",
              emptyBody: "实时翻译将在这里显示。",
              transcriptLabel: "实时翻译",
              jumpLabel: "回到最新",
              newEntries: count => `· ${count} 条新内容`,
              waitingDirection: "等待开始",
              mandarinToEnglish: "中 → 英",
              mandarinToEnglishLabel: "翻译方向：中文到英文",
              englishToMandarin: "英 → 中",
              englishToMandarinLabel: "翻译方向：英文到中文",
              connecting: "正在连接",
              connected: "已连接",
              reconnecting: "正在重新连接",
              cannotJoin: "当前无法加入，请确认 Mac 上已开启听众共享",
              roomFull: "连接人数已满",
              syncing: "正在同步",
              deviceName: "Safari 设备",
              phaseLabels: Object.freeze({
                idle: "等待开始",
                preparing: "正在准备",
                listening: "正在聆听",
                recognizing: "正在识别",
                translating: "正在翻译",
                stopping: "正在完成",
                failed: "已暂停"
              })
            }),
            en: Object.freeze({
              htmlLanguage: "en",
              readerLabel: "Live meeting transcription and translation",
              readerTitle: "Meeting Translation",
              textToolsLabel: "Adjust reading display",
              timestampsLabel: "Passage timestamps",
              timestampToggleLabel: "Time",
              timestampA11y: "Timestamp",
              smallerLabel: "Decrease subtitle size",
              largerLabel: "Increase subtitle size",
              emptyTitle: "Waiting for the speaker",
              emptyBody: "Live translation will appear here.",
              transcriptLabel: "Live translation",
              jumpLabel: "Back to latest",
              newEntries: count => `· ${count} new`,
              waitingDirection: "Waiting to begin",
              mandarinToEnglish: "Chinese → English",
              mandarinToEnglishLabel: "Translation direction: Chinese to English",
              englishToMandarin: "English → Chinese",
              englishToMandarinLabel: "Translation direction: English to Chinese",
              connecting: "Connecting",
              connected: "Connected",
              reconnecting: "Reconnecting",
              cannotJoin: "Unable to join. Confirm listener sharing is enabled on the Mac.",
              roomFull: "The room is full",
              syncing: "Syncing",
              deviceName: "Safari device",
              phaseLabels: Object.freeze({
                idle: "Waiting to begin",
                preparing: "Preparing",
                listening: "Listening",
                recognizing: "Recognizing",
                translating: "Translating",
                stopping: "Finishing",
                failed: "Paused"
              })
            })
          });
          let copy = copyByTargetLanguage.zh;

        """#
}
