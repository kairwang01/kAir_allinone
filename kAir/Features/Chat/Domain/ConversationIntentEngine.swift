//
//  ConversationIntentEngine.swift
//  kAir
//
//  Unified prompt router for chat-driven capability surfaces.
//

import Foundation

struct ConversationIntentResolution {
    let route: ConversationRoute?
    let message: ConversationMessage?
    let pendingMapTask: MapTask?
    let resolvedMapTask: MapTask?
    let resolvedMusicSession: MusicPlaybackSession?
    let resolvedVideoSession: VideoPlaybackSession?
}

enum ConversationIntentEngine {
    static func handleAction(
        _ action: ConversationToolAction,
        pendingMapTask: MapTask?,
        runtime: MapsRuntime
    ) async -> ConversationIntentResolution? {
        guard let response = await MapsIntentRouter.handleAction(
            action,
            pendingTask: pendingMapTask,
            runtime: runtime
        ) else {
            return nil
        }

        return ConversationIntentResolution(
            route: response.decision == .openMaps
                ? ConversationRoute(
                    destination: .surface(.maps),
                    handoffReason: "for location and route work",
                    shouldRecordSystemNote: false
                )
                : nil,
            message: response.message,
            pendingMapTask: response.pendingTask,
            resolvedMapTask: response.openTask,
            resolvedMusicSession: nil,
            resolvedVideoSession: nil
        )
    }

    static func handlePrompt(
        _ prompt: String,
        threadId: UUID,
        pendingMapTask: MapTask?,
        runtime: MapsRuntime
    ) async -> ConversationIntentResolution? {
        if let response = await MapsIntentRouter.handlePrompt(
            prompt,
            threadId: threadId,
            pendingTask: pendingMapTask,
            runtime: runtime
        ) {
            return ConversationIntentResolution(
                route: response.decision == .openMaps
                    ? ConversationRoute(
                        destination: .surface(.maps),
                        handoffReason: "for location and route work",
                        shouldRecordSystemNote: false
                    )
                    : nil,
                message: response.message,
                pendingMapTask: response.pendingTask,
                resolvedMapTask: response.openTask,
                resolvedMusicSession: nil,
                resolvedVideoSession: nil
            )
        }

        if let musicSession = musicSession(for: prompt) {
            let usesChineseCopy = containsChinese(in: prompt)
            let message = ConversationMessage.assistant(
                text: usesChineseCopy
                    ? "AI 已根据你的意图开始播放 \(musicSession.title)。音乐会先停在 thread 里的常驻播放器，不打断当前对话。"
                    : "AI started \(musicSession.title) for this request. The soundtrack will stay in the persistent player so the thread can continue.",
                tags: ["Music", usesChineseCopy ? "常驻播放器" : "Persistent player"],
                toolResults: [musicResult(for: musicSession, usesChineseCopy: usesChineseCopy)]
            )

            return ConversationIntentResolution(
                route: ConversationRoute(
                    destination: .persistentPlayer,
                    handoffReason: "to keep music live while the thread stays active",
                    shouldRecordSystemNote: false
                ),
                message: message,
                pendingMapTask: nil,
                resolvedMapTask: nil,
                resolvedMusicSession: musicSession,
                resolvedVideoSession: nil
            )
        }

        if let videoSession = videoSession(for: prompt) {
            let usesChineseCopy = containsChinese(in: prompt)
            let message = ConversationMessage.system(
                text: usesChineseCopy
                    ? "进入 Video 播放这个请求。原线程保留，返回后只回写摘要。"
                    : "Entering Video for this request. The original thread stays here and only the summary writes back.",
                tags: ["Video handoff"],
                toolResults: [videoResult(for: videoSession, usesChineseCopy: usesChineseCopy)]
            )

            return ConversationIntentResolution(
                route: ConversationRoute(
                    destination: .surface(.video),
                    handoffReason: "for an immersive video response",
                    shouldRecordSystemNote: false
                ),
                message: message,
                pendingMapTask: nil,
                resolvedMapTask: nil,
                resolvedMusicSession: nil,
                resolvedVideoSession: videoSession
            )
        }

        return nil
    }

    private static func musicSession(for prompt: String) -> MusicPlaybackSession? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        let englishTrigger = normalized.contains("play") &&
            (normalized.contains("music") ||
                normalized.contains("playlist") ||
                normalized.contains("jazz") ||
                normalized.contains("lofi") ||
                normalized.contains("focus") ||
                normalized.contains("ambient") ||
                normalized.contains("song"))
        let chineseTrigger = ["播放", "音乐", "歌单", "爵士", "白噪音", "专注", "放松"]
            .contains { trimmed.contains($0) }

        guard englishTrigger || chineseTrigger else {
            return nil
        }

        let mood: MusicPlaybackSession.Mood
        let title: String
        let subtitle: String

        if normalized.contains("jazz") || trimmed.contains("爵士") {
            mood = .jazz
            title = containsChinese(in: trimmed) ? "爵士流" : "Jazz Flow"
            subtitle = containsChinese(in: trimmed) ? "低干扰、适合继续聊天" : "Low-interruption playback for continuing the chat"
        } else if normalized.contains("focus") || normalized.contains("study") || trimmed.contains("专注") {
            mood = .focus
            title = containsChinese(in: trimmed) ? "专注模式" : "Focus Mode"
            subtitle = containsChinese(in: trimmed) ? "更适合工作和追问" : "Tuned for work, planning, and follow-up questions"
        } else if normalized.contains("calm") || normalized.contains("relax") || trimmed.contains("放松") {
            mood = .calm
            title = containsChinese(in: trimmed) ? "放松播放" : "Calm Playback"
            subtitle = containsChinese(in: trimmed) ? "安静背景，不抢主对话" : "Quiet background audio that does not fight the thread"
        } else if normalized.contains("run") || normalized.contains("workout") || trimmed.contains("运动") {
            mood = .energy
            title = containsChinese(in: trimmed) ? "运动节奏" : "Energy Run"
            subtitle = containsChinese(in: trimmed) ? "偏动态的训练背景" : "Higher-energy playback for movement and workouts"
        } else if normalized.contains("ambient") || normalized.contains("lofi") || trimmed.contains("白噪音") {
            mood = .ambient
            title = containsChinese(in: trimmed) ? "环境氛围" : "Ambient Layer"
            subtitle = containsChinese(in: trimmed) ? "持续背景层，不打断思路" : "Continuous background layer for staying in flow"
        } else {
            mood = .custom
            title = containsChinese(in: trimmed) ? "AI 音乐播放" : "AI Music Session"
            subtitle = containsChinese(in: trimmed) ? "根据当前语境生成的轻量播放建议" : "Lightweight playback mix inferred from the current thread"
        }

        return MusicPlaybackSession(
            title: title,
            subtitle: subtitle,
            mood: mood,
            query: trimmed
        )
    }

    private static func videoSession(for prompt: String) -> VideoPlaybackSession? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        let englishVideoTokens = [
            "video",
            "watch",
            "tutorial",
            "walkthrough",
            "demo",
            "workout video",
        ]
        let chineseVideoTokens = [
            "视频",
            "教程",
            "演示",
            "示范",
            "训练视频",
        ]

        let matchesEnglish = englishVideoTokens.contains(where: normalized.contains)
        let matchesChinese = chineseVideoTokens.contains(where: trimmed.contains)
        guard matchesEnglish || matchesChinese else {
            return nil
        }

        let category: VideoPlaybackSession.Category
        let title: String
        let summary: String
        let durationLabel: String

        if normalized.contains("yoga") || normalized.contains("stretch") || trimmed.contains("瑜伽") || trimmed.contains("拉伸") {
            category = .workout
            title = containsChinese(in: trimmed) ? "拉伸视频" : "Stretch Session"
            summary = containsChinese(in: trimmed)
                ? "进入沉浸式视频层，先看动作，再回到 chat 继续追问。"
                : "Open an immersive workout surface, then return to chat for follow-up coaching."
            durationLabel = containsChinese(in: trimmed) ? "12 分钟" : "12 min"
        } else if normalized.contains("tutorial") || normalized.contains("how to") || trimmed.contains("教程") {
            category = .tutorial
            title = containsChinese(in: trimmed) ? "教程视频" : "Tutorial Video"
            summary = containsChinese(in: trimmed)
                ? "把需要看的部分拉成单独 surface，避免 thread 被长说明淹没。"
                : "Pull the visual explanation into its own surface so the thread stays readable."
            durationLabel = containsChinese(in: trimmed) ? "8 分钟" : "8 min"
        } else if normalized.contains("ambient") || trimmed.contains("氛围") {
            category = .ambient
            title = containsChinese(in: trimmed) ? "氛围视频" : "Ambient Video"
            summary = containsChinese(in: trimmed)
                ? "进入沉浸式视频层，但原会话仍保留。"
                : "Open an immersive video layer while keeping the original conversation intact."
            durationLabel = containsChinese(in: trimmed) ? "15 分钟" : "15 min"
        } else {
            category = .explainer
            title = containsChinese(in: trimmed) ? "视频说明" : "Video Response"
            summary = containsChinese(in: trimmed)
                ? "这个请求更适合用可视化 surface 承接。"
                : "This request is better served by a visual, focused surface."
            durationLabel = containsChinese(in: trimmed) ? "6 分钟" : "6 min"
        }

        return VideoPlaybackSession(
            title: title,
            summary: summary,
            query: trimmed,
            category: category,
            durationLabel: durationLabel
        )
    }

    private static func musicResult(
        for session: MusicPlaybackSession,
        usesChineseCopy: Bool
    ) -> ConversationToolResult {
        ConversationToolResult(
            id: "music-player-\(session.id.uuidString)",
            title: usesChineseCopy ? "Music 已进入常驻播放器" : "Music entered the persistent player",
            summary: session.subtitle,
            state: .ready,
            metrics: [
                .init(key: usesChineseCopy ? "模式" : "Mode", value: session.mood.title),
                .init(key: usesChineseCopy ? "承接" : "Carry", value: usesChineseCopy ? "留在当前线程" : "Stay in this thread"),
                .init(key: usesChineseCopy ? "打开" : "Open", value: usesChineseCopy ? "可随时展开 Music" : "Open Music anytime")
            ],
            footer: usesChineseCopy
                ? "Music 不会把你带离聊天首页；它只是挂在 shell 上方继续播放。"
                : "Music does not replace chat as the home surface. It hangs off the shell while the conversation continues."
        )
    }

    private static func videoResult(
        for session: VideoPlaybackSession,
        usesChineseCopy: Bool
    ) -> ConversationToolResult {
        ConversationToolResult(
            id: "video-surface-\(session.id.uuidString)",
            title: usesChineseCopy ? "Video 已接管" : "Video focused surface",
            summary: session.summary,
            state: .ready,
            metrics: [
                .init(key: usesChineseCopy ? "类别" : "Category", value: session.category.title),
                .init(key: usesChineseCopy ? "时长" : "Duration", value: session.durationLabel),
                .init(key: usesChineseCopy ? "线程" : "Thread", value: usesChineseCopy ? "原会话保留" : "Original thread kept")
            ],
            footer: usesChineseCopy
                ? "Video 是被意图触发的 focused surface，不是常驻 tab。"
                : "Video is an intent-triggered focused surface, not a permanent tab."
        )
    }

    private static func containsChinese(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
        }
    }
}
