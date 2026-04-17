//
//  ChatStore.swift
//  kAir
//
//  Local orchestration for the kAir conversation surface.
//

import Foundation
import Observation

@MainActor
@Observable
final class ChatStore {
    let modes: [ComposerMode] = [
        ComposerMode(id: "ask", title: "Ask", systemImage: "bubble.left"),
        ComposerMode(id: "coach", title: "Coach", systemImage: "waveform.path.ecg"),
        ComposerMode(id: "route", title: "Route", systemImage: "arrow.triangle.branch"),
        ComposerMode(id: "shop", title: "Shop", systemImage: "bag"),
    ]

    let accessories: [ComposerAccessory] = [
        ComposerAccessory(id: "health", title: "Health", systemImage: "heart.text.square"),
        ComposerAccessory(id: "ai", title: "AI", systemImage: "cpu"),
        ComposerAccessory(id: "maps", title: "Maps", systemImage: "map"),
        ComposerAccessory(id: "store", title: "Store", systemImage: "bag"),
    ]

    var session = ChatSession(title: "kAir", messages: [])
    var draft = ""
    var isTemplateChat = false {
        didSet {
            handleTemplateChatChange()
        }
    }
    var selectedModeID = "ask"
    var contextSummary = "One thread across AI, Maps, Store, and optional Health"
    var suggestedPrompts: [String] = [
        "我想去超市",
        "Which model is active?",
        "Find a nearby pharmacy",
        "What can kAir do for me?"
    ]

    private var lastRefreshDate: Date?
    private var supportsHealthData = true
    private var pendingMapsIntent: PendingMapsIntent?
    private var resolvedMapsSession: MapsRouteSession?
    private var resolvedHealthSession: HealthRouteSession?
    private let persistence = ChatSessionPersistence()

    init() {
        if let restoredSession = persistence.load() {
            session = restoredSession
        }
    }

    func bootstrap(with dashboard: HealthDashboard) {
        supportsHealthData = true
        contextSummary = "AI, Maps, and Store are live. Apple Health is available on-device only when you ask for it."
        suggestedPrompts = Self.suggestedPrompts(for: dashboard)

        guard lastRefreshDate != dashboard.generatedAt else { return }

        if session.messages.isEmpty {
            session.messages = [
                .assistant(
                    text: Self.welcomeMessage(for: dashboard),
                    timestamp: dashboard.generatedAt,
                    tags: ["All-in-one", "Local-first"],
                    toolResults: [Self.runtimeShellResult(healthReady: true)]
                ),
            ]
            persistIfNeeded()
        }

        lastRefreshDate = dashboard.generatedAt
    }

    func bootstrapWithoutDashboard(supportsHealthData: Bool) {
        self.supportsHealthData = supportsHealthData
        contextSummary = supportsHealthData
            ? "Chat-first shell · AI, Maps, and Store are ready; Health stays on-demand"
            : "HealthKit unavailable · AI, Maps, and Store remain available"
        suggestedPrompts = Self.fallbackSuggestedPrompts(supportsHealthData: supportsHealthData)

        guard session.messages.isEmpty else { return }

        session.messages = [
            .assistant(
                text: Self.welcomeMessageWithoutDashboard(supportsHealthData: supportsHealthData),
                tags: ["Chat-first", "Local-first"],
                toolResults: [Self.runtimeShellResult(healthReady: false, supportsHealthData: supportsHealthData)]
            ),
        ]
        persistIfNeeded()
    }

    func selectMode(_ mode: ComposerMode) {
        selectedModeID = mode.id
    }

    func sendDraft(
        using dashboard: HealthDashboard?,
        target: ChatNavigationTarget? = nil
    ) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        submit(prompt: trimmed, using: dashboard, target: target)
    }

    func submitPrompt(
        _ prompt: String,
        using dashboard: HealthDashboard?,
        target: ChatNavigationTarget? = nil
    ) {
        submit(prompt: prompt, using: dashboard, target: target)
    }

    func recordHandoff(to target: ChatNavigationTarget) {
        let text: String
        switch target {
        case .section(let section):
            text = "Opened \(section.title) as a focused surface. You are still in this same conversation and can return to chat anytime."
        case .userProfile:
            text = "Opened User as a profile sheet. You are still in this same conversation and can return to chat anytime."
        }

        session.messages.append(
            .system(
                text: text,
                tags: ["\(target.title) handoff"]
            )
        )
        persistIfNeeded()
    }

    func attachReference(_ title: String, detail: String) {
        session.messages.append(
            .system(
                text: "\(title) attached. \(detail)",
                tags: ["Reference"]
            )
        )
        persistIfNeeded()
    }

    func consumeResolvedMapsSession() -> MapsRouteSession? {
        let session = resolvedMapsSession
        resolvedMapsSession = nil
        return session
    }

    func consumeResolvedHealthSession() -> HealthRouteSession? {
        let session = resolvedHealthSession
        resolvedHealthSession = nil
        return session
    }

    func route(for prompt: String) -> ChatNavigationTarget? {
        resolvedHealthSession = nil

        if pendingMapsIntent != nil, travelMode(from: prompt) != nil {
            return .section(.maps)
        }

        if explicitMapsIntent(from: prompt) != nil {
            return nil
        }

        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()

        if isUserCommand(normalized, prompt: trimmed) {
            return .userProfile
        }

        if let healthSession = exactHealthCommand(normalized: normalized, prompt: trimmed) {
            resolvedHealthSession = healthSession
            return .section(.health)
        }

        if isMapsCommand(normalized, prompt: trimmed) {
            return .section(.maps)
        }

        if Self.isGenericMapsPrompt(normalized, prompt: prompt) {
            return .section(.maps)
        }

        if normalized.contains("buy") ||
            normalized.contains("shop") ||
            normalized.contains("order") ||
            normalized.contains("supplement") ||
            normalized.contains("device") ||
            normalized.contains("bundle")
        {
            return .section(.store)
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return .section(.ai)
        }

        if let healthSession = explicitHealthIntent(from: prompt) {
            resolvedHealthSession = healthSession
            return .section(.health)
        }

        return nil
    }

    private func submit(
        prompt: String,
        using dashboard: HealthDashboard?,
        target: ChatNavigationTarget?
    ) {
        session.messages.append(
            .user(
                text: prompt,
                tags: selectedModeID == "ask" ? [] : [selectedMode.title]
            )
        )

        if let mapsMessage = handleMapsFlow(prompt: prompt) {
            session.messages.append(mapsMessage)
            persistIfNeeded()
            return
        }

        if case .section(.health) = target, let healthSession = resolvedHealthSession {
            session.messages.append(
                .assistant(
                    text: healthHandoffText(for: healthSession, dashboard: dashboard),
                    tags: healthHandoffTags(for: healthSession),
                    toolResults: [healthHandoffResult(for: healthSession, dashboard: dashboard)]
                )
            )
            persistIfNeeded()
            return
        }

        if case .userProfile = target {
            session.messages.append(
                .assistant(
                    text: "Opening User settings while keeping this thread intact.",
                    tags: ["User", "Focused surface"],
                    toolResults: [userProfileResult()]
                )
            )
            persistIfNeeded()
            return
        }

        session.messages.append(
            .assistant(
                text: dashboard.map {
                    Self.reply(to: prompt, modeID: selectedModeID, dashboard: $0)
                } ?? Self.replyWithoutDashboard(
                    to: prompt,
                    modeID: selectedModeID,
                    supportsHealthData: supportsHealthData
                ),
                tags: dashboard.map {
                    Self.replyTags(for: prompt, modeID: selectedModeID, dashboard: $0)
                } ?? Self.replyTagsWithoutDashboard(
                    for: prompt,
                    modeID: selectedModeID,
                    supportsHealthData: supportsHealthData
                ),
                toolResults: dashboard.map {
                    Self.toolResults(for: prompt, dashboard: $0)
                } ?? Self.toolResultsWithoutDashboard(
                    for: prompt,
                    supportsHealthData: supportsHealthData
                )
            )
        )
        persistIfNeeded()
    }

    private var selectedMode: ComposerMode {
        modes.first(where: { $0.id == selectedModeID }) ?? modes[0]
    }

    private static func suggestedPrompts(for dashboard: HealthDashboard) -> [String] {
        [
            "I want to go to Apple Store",
            "Which model should answer a health question?",
            "Find a nearby pharmacy",
            "What can kAir do for me?"
        ]
    }

    private static func fallbackSuggestedPrompts(supportsHealthData: Bool) -> [String] {
        if supportsHealthData {
            [
                "I want to go to Apple Store",
                "Find a nearby pharmacy",
                "Which model is active?",
                "What can kAir do for me?"
            ]
        } else {
            [
                "I want to go to Apple Store",
                "Show me a nearby pharmacy",
                "Which model is active?",
                "What can kAir do for me?"
            ]
        }
    }

    private static func welcomeMessage(for dashboard: HealthDashboard) -> String {
        "You are in kAir. Chat is the main surface. I can route into AI, Maps, and Store from this thread, and Apple Health stays available as an on-device tool only when you ask for it."
    }

    private static func welcomeMessageWithoutDashboard(supportsHealthData: Bool) -> String {
        if supportsHealthData {
            return "You are in kAir. Chat is already live, and AI, Maps, and Store can open from this thread immediately. Apple Health stays optional until you explicitly ask for health context."
        }
        return "You are in kAir. This device cannot attach Apple Health right now, but the chat, AI, Maps, and Store surfaces still live in one thread."
    }

    private static func reply(to prompt: String, modeID: String, dashboard: HealthDashboard) -> String {
        let normalized = prompt.lowercased()

        if normalized.contains("sleep") {
            return "Sleep averaged \(dashboard.sleepSummary.averageHours.formattedOneDecimal) h/night across \(dashboard.sleepSummary.nightsTracked) nights. The latest night was \(dashboard.sleepSummary.latestHours.formattedOneDecimal) h. \(dashboard.sleepSummary.summary)"
        }

        if normalized.contains("recovery") || normalized.contains("hrv") || normalized.contains("health") {
            if let recovery = dashboard.insights.first(where: { $0.id == "recovery" }) {
                return "\(recovery.summary) I would read that alongside resting heart rate, sleep regularity, and the model watchpoints before deciding what deserves attention."
            }
        }

        if normalized.contains("activity") || normalized.contains("steps") || normalized.contains("workout") {
            let newestWorkout = dashboard.workouts.first?.activity ?? "No recent workout"
            return "The recent activity picture is anchored by \(dashboard.workouts.count) workouts, with \(newestWorkout) as the newest session. \(dashboard.insights.first(where: { $0.id == "activity" })?.summary ?? "Movement data is available in Health.")"
        }

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            return "Maps should stay quiet and utilitarian inside kAir: nearby clinics, pharmacies, gyms, and walking routes, surfaced as task-ready places instead of a noisy standalone map first."
        }

        if normalized.contains("model") || normalized.contains("ai") || modeID == "route" {
            if let prediction = dashboard.predictions.first {
                return "The active AI posture is local-first. One orchestrator keeps the thread intact, decides which surface to open next, and only reaches for specialized health reasoning when you explicitly ask for health context. \(prediction.title) remains available as an on-device specialist."
            }
            return "The AI layer is designed as a routing surface: one general model for conversation, one planner for opening Maps or Store, and an optional on-device health explainer only when the thread calls for it."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("supplement") || normalized.contains("device") || modeID == "shop" {
            return "Store should feel curated, not loud. I would prioritize sleep and recovery tools first, then wearables, then lightweight nutrition suggestions, all anchored to what your health data actually suggests is worth watching."
        }

        if normalized.contains("privacy") || normalized.contains("local") {
            return "kAir stays local-first. The shell keeps chat, AI, Maps, and Store together, while Health remains an on-device capability that only comes into play when you explicitly ask for it."
        }

        return "kAir is set up as one conversation that can open deeper tools only when needed. I can stage nearby routes, explain the AI runtime, prepare store suggestions, or bring in Health only if you want that context."
    }

    private static func replyWithoutDashboard(
        to prompt: String,
        modeID: String,
        supportsHealthData: Bool
    ) -> String {
        let normalized = prompt.lowercased()

        if normalized.contains("connect") || normalized.contains("health") || normalized.contains("sleep") || normalized.contains("heart") {
            if supportsHealthData {
                return "Health is available on this device, but it is not attached yet. Open the Health surface or use the profile controls to grant Apple Health access, then this thread can answer with grounded local data."
            }
            return "This device cannot attach Apple Health right now, so health answers cannot be grounded locally here."
        }

        if isGenericMapsPrompt(normalized, prompt: prompt) || modeID == "route" {
            return "Maps can still be invoked immediately from chat. I will preserve this thread, then hand off into a focused navigation surface."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("shop") || modeID == "shop" {
            return "Store can still open from the conversation, but curation will be broader until Apple Health is attached."
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return "The AI layer is already live. One orchestrator handles the thread, then opens deeper surfaces only when the task needs them."
        }

        return supportsHealthData
            ? "kAir is already chat-first. AI, Maps, and Store are available now, and Health remains optional until you explicitly ask for it."
            : "kAir is already chat-first. AI, Maps, and Store are available now, but Health grounding is unavailable on this device."
    }

    private static func replyTags(for prompt: String, modeID: String, dashboard: HealthDashboard) -> [String] {
        let normalized = prompt.lowercased()
        var tags = ["Local-first"]

        if modeID != "ask" {
            tags.append(modeID.capitalized)
        }

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            tags.append("Maps")
        } else if normalized.contains("store") || normalized.contains("buy") || normalized.contains("supplement") {
            tags.append("Store")
        } else if normalized.contains("model") || normalized.contains("ai") {
            tags.append("AI")
        } else if isHealthPrompt(normalized) {
            tags.append("Health")
        } else {
            tags.append("General")
        }

        if let prediction = dashboard.predictions.first {
            tags.append(prediction.title)
        }

        return tags
    }

    private static func replyTagsWithoutDashboard(
        for prompt: String,
        modeID: String,
        supportsHealthData: Bool
    ) -> [String] {
        let normalized = prompt.lowercased()
        var tags = ["Chat-first"]

        if modeID != "ask" {
            tags.append(modeID.capitalized)
        }

        if normalized.contains("map") || normalized.contains("route") || normalized.contains("nearby") {
            tags.append("Maps")
        } else if normalized.contains("store") || normalized.contains("buy") || normalized.contains("shop") {
            tags.append("Store")
        } else if normalized.contains("model") || normalized.contains("ai") {
            tags.append("AI")
        } else if isHealthPrompt(normalized) {
            tags.append(supportsHealthData ? "Health" : "Health unavailable")
        } else {
            tags.append("General")
        }

        return tags
    }

    private static func toolResults(for prompt: String, dashboard: HealthDashboard) -> [ConversationToolResult] {
        let normalized = prompt.lowercased()

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            return [mapsResult()]
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return [aiRuntimeResult(for: dashboard)]
        }

        if normalized.contains("store") || normalized.contains("buy") || normalized.contains("supplement") || normalized.contains("device") {
            return [storeResult()]
        }

        if normalized.contains("sleep") {
            return [sleepResult(for: dashboard)]
        }

        if isHealthPrompt(normalized) {
            return [healthSnapshotResult(for: dashboard)]
        }

        return [runtimeShellResult(healthReady: true)]
    }

    private static func toolResultsWithoutDashboard(
        for prompt: String,
        supportsHealthData: Bool
    ) -> [ConversationToolResult] {
        let normalized = prompt.lowercased()

        if isGenericMapsPrompt(normalized, prompt: prompt) {
            return [mapsResult()]
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return [ungroundedAIResult()]
        }

        if normalized.contains("store") || normalized.contains("buy") || normalized.contains("shop") {
            return [storeResult()]
        }

        if isHealthPrompt(normalized) {
            return [healthAccessResult(supportsHealthData: supportsHealthData)]
        }

        return [runtimeShellResult(healthReady: false, supportsHealthData: supportsHealthData)]
    }

    private static func runtimeShellResult(
        healthReady: Bool,
        supportsHealthData: Bool = true
    ) -> ConversationToolResult {
        ConversationToolResult(
            id: healthReady ? "runtime_shell_ready" : "runtime_shell_base",
            title: "kAir Runtime",
            summary: "The app is chat-first. It opens AI, Maps, Store, and Health only when the current request needs them.",
            state: .ready,
            metrics: [
                .init(key: "Chat", value: "Primary"),
                .init(key: "Maps", value: "Ready"),
                .init(key: "Store", value: "Ready"),
                .init(key: "Health", value: healthReady ? "On-demand" : (supportsHealthData ? "Available later" : "Unavailable"))
            ],
            footer: healthReady
                ? "Apple Health is available locally, but it is not foregrounded unless the user asks."
                : "Health stays dormant until the thread explicitly asks for it."
        )
    }

    private static func healthSnapshotResult(for dashboard: HealthDashboard) -> ConversationToolResult {
        ConversationToolResult(
            id: "health_snapshot",
            title: "Health Snapshot",
            summary: dashboard.hero.summary,
            state: dashboard.hero.band.lowercased() == "guarded" ? .warning : .ready,
            metrics: [
                .init(key: "Band", value: dashboard.hero.band),
                .init(key: "Confidence", value: dashboard.hero.confidence.formattedPercent0),
                .init(key: "Refreshed", value: dashboard.generatedAt.formatted(.dateTime.hour().minute()))
            ],
            footer: "Local Apple Health only."
        )
    }

    private static func sleepResult(for dashboard: HealthDashboard) -> ConversationToolResult {
        ConversationToolResult(
            id: "sleep_summary",
            title: "Sleep Summary",
            summary: dashboard.sleepSummary.summary,
            state: .ready,
            metrics: [
                .init(key: "Average", value: "\(dashboard.sleepSummary.averageHours.formattedOneDecimal) h"),
                .init(key: "Latest", value: "\(dashboard.sleepSummary.latestHours.formattedOneDecimal) h"),
                .init(key: "Debt", value: "\(dashboard.sleepSummary.debtHours.formattedOneDecimal) h")
            ],
            footer: "Computed from recent Apple Health sleep segments."
        )
    }

    private static func aiRuntimeResult(for dashboard: HealthDashboard) -> ConversationToolResult {
        ConversationToolResult(
            id: "ai_runtime",
            title: "AI Runtime",
            summary: "The AI layer uses one conversation surface and opens deeper tools only when the task needs it.",
            state: .ready,
            metrics: [
                .init(key: "Primary", value: dashboard.modelSummary?.engine ?? "Local-first"),
                .init(key: "Health", value: "Grounded"),
                .init(key: "Cloud", value: "Off by default")
            ],
            footer: "Use AI for routing and explanation, not for replacing the health data source."
        )
    }

    private static func ungroundedAIResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "ai_runtime_base",
            title: "AI Runtime",
            summary: "The conversation layer is live even before Health is attached.",
            state: .ready,
            metrics: [
                .init(key: "Primary", value: "kAir Orchestrator"),
                .init(key: "Health", value: "Attach later"),
                .init(key: "Cloud", value: "Off by default")
            ],
            footer: "Attach Apple Health when you want evidence-backed health answers."
        )
    }

    private static func mapsResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "maps_surface",
            title: "Maps Surface",
            summary: "Prepared nearby places and route context inside the app shell.",
            state: .working,
            metrics: [
                .init(key: "Places", value: "Clinics · Pharmacy · Gym"),
                .init(key: "Mode", value: "Task-first"),
                .init(key: "Map", value: "Surface ready")
            ],
            footer: "Live location search and route execution are still placeholders in this pass."
        )
    }

    private static func storeResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "store_surface",
            title: "Store Curation",
            summary: "Prepared a curated store layer for recovery, wearables, and nutrition.",
            state: .working,
            metrics: [
                .init(key: "Focus", value: "Sleep + Recovery"),
                .init(key: "Style", value: "Curated"),
                .init(key: "Checkout", value: "Not wired")
            ],
            footer: "Commerce and checkout are intentionally out of scope for the current rebuild."
        )
    }

    private static func healthAccessResult(supportsHealthData: Bool) -> ConversationToolResult {
        ConversationToolResult(
            id: "health_access",
            title: supportsHealthData ? "Apple Health Access" : "HealthKit Unavailable",
            summary: supportsHealthData
                ? "Chat is live now. Attach Apple Health whenever you want local health grounding."
                : "This device cannot provide Apple Health grounding.",
            state: supportsHealthData ? .working : .warning,
            metrics: [
                .init(key: "Chat", value: "Ready"),
                .init(key: "Health", value: supportsHealthData ? "Connect" : "Unavailable"),
                .init(key: "Maps", value: "Ready")
            ],
            footer: supportsHealthData
                ? "Open the Health surface to grant Apple Health access."
                : "Use AI, Maps, and Store without local Apple Health."
        )
    }

    private func userProfileResult() -> ConversationToolResult {
        ConversationToolResult(
            id: "user_profile_surface",
            title: "User",
            summary: "Prepared the user settings sheet from inside the current thread.",
            state: .ready,
            metrics: [
                .init(key: "Surface", value: "Profile sheet"),
                .init(key: "Thread", value: "Same conversation"),
                .init(key: "Storage", value: isTemplateChat ? "Template only" : "Saved locally")
            ],
            footer: "Use this testing route to jump into the user interface from chat."
        )
    }

    private static func leadingInsight(in dashboard: HealthDashboard) -> InsightCard? {
        dashboard.insights.max(by: { $0.score < $1.score })
    }

    private static func isHealthPrompt(_ normalized: String) -> Bool {
        normalized.contains("sleep") ||
            normalized.contains("recovery") ||
            normalized.contains("health") ||
            normalized.contains("heart") ||
            normalized.contains("hrv") ||
            normalized.contains("ecg")
    }

    private func healthHandoffText(
        for session: HealthRouteSession,
        dashboard: HealthDashboard?
    ) -> String {
        let topic = session.topic.title(for: session.language)

        switch session.language {
        case .chinese:
            if dashboard != nil {
                return "这是一个\(topic)状态查询。我会把它交给 Health 页面，用本地 Apple Health 证据和趋势来完成；你仍然留在同一个会话里。"
            }

            if supportsHealthData {
                return "这是一个\(topic)状态查询。我先把它交给 Health 页面；如果这台设备还没授权，页面会先说明为什么需要 Apple Health 权限。"
            }

            return "这是一个\(topic)状态查询。我会打开 Health 页面，但这台设备当前不能提供本地 Apple Health 证据。"
        case .english:
            if dashboard != nil {
                return "This is a focused \(topic.lowercased()) check. I’m handing it to Health so the page can answer with local evidence and trends while keeping this thread intact."
            }

            if supportsHealthData {
                return "This is a focused \(topic.lowercased()) check. I’m handing it to Health now, and the page will explain Apple Health access first if this device has not been authorized yet."
            }

            return "This is a focused \(topic.lowercased()) check. I can open Health, but this device cannot provide local Apple Health evidence right now."
        }
    }

    private func healthHandoffResult(
        for session: HealthRouteSession,
        dashboard: HealthDashboard?
    ) -> ConversationToolResult {
        switch session.language {
        case .chinese:
            if dashboard != nil {
                return ConversationToolResult(
                    id: "health_handoff_ready",
                    title: "Health 已接管",
                    summary: "聊天已把这次查询切到 Health 页面，由本地数据完成结论、证据和限制说明。",
                    state: .ready,
                    metrics: [
                        .init(key: "主题", value: session.topic.title(for: .chinese)),
                        .init(key: "数据", value: "本地 Apple Health"),
                        .init(key: "线程", value: "保持同一会话")
                    ],
                    footer: "聊天层只保留摘要与 handoff 记录，不暴露原始 Health 数据。"
                )
            }

            if supportsHealthData {
                return ConversationToolResult(
                    id: "health_handoff_auth",
                    title: "Health 等待授权",
                    summary: "Health 页面会先解释权限用途，再继续本地分析。",
                    state: .working,
                    metrics: [
                        .init(key: "主题", value: session.topic.title(for: .chinese)),
                        .init(key: "下一步", value: "授权 Apple Health"),
                        .init(key: "线程", value: "保持同一会话")
                    ],
                    footer: "权限是 just-in-time 触发，不会在聊天首页强行索取。"
                )
            }

            return ConversationToolResult(
                id: "health_handoff_unavailable",
                title: "Health 不可用",
                summary: "这台设备当前不能提供本地 Apple Health 证据。",
                state: .warning,
                metrics: [
                    .init(key: "主题", value: session.topic.title(for: .chinese)),
                    .init(key: "Health", value: "不可用"),
                    .init(key: "线程", value: "保持同一会话")
                ],
                footer: "聊天仍可继续，但这里不能给出本地健康结论。"
            )
        case .english:
            if dashboard != nil {
                return ConversationToolResult(
                    id: "health_handoff_ready",
                    title: "Health Focused Surface",
                    summary: "The chat thread handed this request to Health, where the conclusion, evidence, and limitations stay grounded locally.",
                    state: .ready,
                    metrics: [
                        .init(key: "Topic", value: session.topic.title(for: .english)),
                        .init(key: "Data", value: "Local Apple Health"),
                        .init(key: "Thread", value: "Same conversation")
                    ],
                    footer: "Chat receives only summarized output and the handoff record, not raw Health data."
                )
            }

            if supportsHealthData {
                return ConversationToolResult(
                    id: "health_handoff_auth",
                    title: "Health Authorization",
                    summary: "Health will explain the permission step first, then continue the local analysis flow.",
                    state: .working,
                    metrics: [
                        .init(key: "Topic", value: session.topic.title(for: .english)),
                        .init(key: "Next", value: "Authorize Apple Health"),
                        .init(key: "Thread", value: "Same conversation")
                    ],
                    footer: "The permission request is just-in-time. It does not interrupt chat unless the user asks for Health."
                )
            }

            return ConversationToolResult(
                id: "health_handoff_unavailable",
                title: "Health Unavailable",
                summary: "This device cannot provide local Apple Health evidence for the requested health check.",
                state: .warning,
                metrics: [
                    .init(key: "Topic", value: session.topic.title(for: .english)),
                    .init(key: "Health", value: "Unavailable"),
                    .init(key: "Thread", value: "Same conversation")
                ],
                footer: "The conversation can continue, but this request cannot be grounded in local Health data here."
            )
        }
    }

    private func healthHandoffTags(for session: HealthRouteSession) -> [String] {
        switch session.language {
        case .chinese:
            return ["Health", session.topic.title(for: .chinese), "Focused surface"]
        case .english:
            return ["Health", session.topic.title(for: .english), "Focused surface"]
        }
    }

    private func handleMapsFlow(prompt: String) -> ConversationMessage? {
        if let pendingMapsIntent {
            guard let mode = travelMode(from: prompt) else {
                return .assistant(
                    text: followUpReminderText(for: pendingMapsIntent),
                    tags: mapsTags(language: pendingMapsIntent.language, stage: "Clarify mode"),
                    toolResults: [pendingMapsResult(for: pendingMapsIntent)]
                )
            }

            let session = MapsRouteSession.mock(
                destination: pendingMapsIntent.destination,
                mode: mode,
                language: pendingMapsIntent.language
            )
            resolvedMapsSession = session
            self.pendingMapsIntent = nil

            return .assistant(
                text: resolvedMapsText(for: session),
                tags: mapsTags(language: session.language, stage: session.mode.title),
                toolResults: [
                    resolvedMapsResult(for: session),
                    plannerWindowResult(for: session)
                ]
            )
        }

        guard let intent = explicitMapsIntent(from: prompt) else {
            return nil
        }

        pendingMapsIntent = intent
        resolvedMapsSession = nil

        return .assistant(
            text: followUpQuestionText(for: intent),
            tags: mapsTags(language: intent.language, stage: "Awaiting mode"),
            toolResults: [pendingMapsResult(for: intent)]
        )
    }

    private func followUpQuestionText(for intent: PendingMapsIntent) -> String {
        switch intent.language {
        case .chinese:
            return "可以，我先把“\(intent.destination)”当作路线请求。你想开车去，还是走路去？"
        case .english:
            return "I can treat \(intent.destination) as a route request. Do you want to drive there or walk?"
        }
    }

    private func followUpReminderText(for intent: PendingMapsIntent) -> String {
        switch intent.language {
        case .chinese:
            return "我还需要先知道你想开车还是走路，这样我才能把两条候选路线推到 Maps 页面。"
        case .english:
            return "I still need the travel mode first. Tell me whether you want to drive or walk, then I can stage two route options for Maps."
        }
    }

    private func resolvedMapsText(for session: MapsRouteSession) -> String {
        switch session.language {
        case .chinese:
            return "明白，按\(session.mode.chineseTitle)模式处理。我已经准备好两条具体路径，并把结果交给 Maps 页面。当前这一步先用文字代替真实地图决策。"
        case .english:
            return "Understood. I staged two concrete \(session.mode.title.lowercased()) routes and handed the result into Maps. This pass still uses text in place of the real map runtime."
        }
    }

    private func pendingMapsResult(for intent: PendingMapsIntent) -> ConversationToolResult {
        switch intent.language {
        case .chinese:
            return ConversationToolResult(
                id: "maps_route_pending",
                title: "路线意图已锁定",
                summary: "目的地已识别为“\(intent.destination)”。下一步只需要确认交通方式。",
                state: .working,
                metrics: [
                    .init(key: "目的地", value: intent.destination),
                    .init(key: "状态", value: "等待开车 / 走路"),
                    .init(key: "输出", value: "Maps 页面")
                ],
                footer: "v0.1 先做文字链路，真实 LLM 和地图服务后接。"
            )
        case .english:
            return ConversationToolResult(
                id: "maps_route_pending",
                title: "Route intent captured",
                summary: "The destination is locked as \(intent.destination). The next step is confirming the travel mode.",
                state: .working,
                metrics: [
                    .init(key: "Destination", value: intent.destination),
                    .init(key: "Status", value: "Awaiting drive / walk"),
                    .init(key: "Output", value: "Maps surface")
                ],
                footer: "v0.1 stages the text flow first, then swaps in the real LLM and map runtime later."
            )
        }
    }

    private func resolvedMapsResult(for session: MapsRouteSession) -> ConversationToolResult {
        let primaryRoute = session.routeOptions.first

        switch session.language {
        case .chinese:
            return ConversationToolResult(
                id: "maps_route_ready",
                title: "路线方案已生成",
                summary: "已为“\(session.destination)”生成两条\(session.mode.chineseTitle)候选路线，并准备好交给 Maps 页面。",
                state: .ready,
                metrics: [
                    .init(key: "模式", value: session.mode.chineseTitle),
                    .init(key: "推荐", value: primaryRoute?.title ?? "候选路径"),
                    .init(key: "预计", value: primaryRoute?.eta ?? "--")
                ],
                footer: "当前 ETA 和距离为占位值，后续改由本地模型和地图数据刷新。"
            )
        case .english:
            return ConversationToolResult(
                id: "maps_route_ready",
                title: "Route plan staged",
                summary: "Two \(session.mode.title.lowercased()) routes are ready for \(session.destination), and the result is prepared for the Maps surface.",
                state: .ready,
                metrics: [
                    .init(key: "Mode", value: session.mode.title),
                    .init(key: "Best", value: primaryRoute?.title ?? "Candidate"),
                    .init(key: "ETA", value: primaryRoute?.eta ?? "--")
                ],
                footer: "ETA and distance are placeholders for now. The on-device model and map data will replace them later."
            )
        }
    }

    private func plannerWindowResult(for session: MapsRouteSession) -> ConversationToolResult {
        switch session.language {
        case .chinese:
            return ConversationToolResult(
                id: "maps_planner_window",
                title: "本地模型窗口",
                summary: session.plannerSummary,
                state: .working,
                metrics: [
                    .init(key: "解析", value: "地点 + 模式"),
                    .init(key: "排序", value: "两条候选路径"),
                    .init(key: "执行", value: "稍后接 Maps")
                ],
                footer: "这里就是后续接大模型与真实路线规划的固定接口。"
            )
        case .english:
            return ConversationToolResult(
                id: "maps_planner_window",
                title: "Local model window",
                summary: session.plannerSummary,
                state: .working,
                metrics: [
                    .init(key: "Parsing", value: "Place + mode"),
                    .init(key: "Ranking", value: "Two route options"),
                    .init(key: "Execution", value: "Maps later")
                ],
                footer: "This is the stable interface where the model and real route planner will plug in next."
            )
        }
    }

    private func mapsTags(language: MapsConversationLanguage, stage: String) -> [String] {
        switch language {
        case .chinese:
            return ["Maps", "路线", stage]
        case .english:
            return ["Maps", "Route", stage]
        }
    }

    private func explicitMapsIntent(from prompt: String) -> PendingMapsIntent? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let language: MapsConversationLanguage = Self.containsChinese(in: trimmed) ? .chinese : .english

        if selectedModeID == "route", travelMode(from: trimmed) == nil {
            return PendingMapsIntent(
                destination: sanitizedDestination(from: trimmed),
                language: language,
                originalPrompt: prompt
            )
        }

        let chinesePrefixes = [
            "我想去",
            "我要去",
            "带我去",
            "导航到",
            "带我到"
        ]
        for prefix in chinesePrefixes where trimmed.hasPrefix(prefix) {
            let destination = sanitizedDestination(from: String(trimmed.dropFirst(prefix.count)))
            guard destination.isEmpty == false else { return nil }
            return PendingMapsIntent(
                destination: destination,
                language: .chinese,
                originalPrompt: prompt
            )
        }

        let normalized = trimmed.lowercased()
        let englishPrefixes = [
            "i want to go to ",
            "i need to go to ",
            "take me to ",
            "navigate to ",
            "go to "
        ]
        for prefix in englishPrefixes where normalized.hasPrefix(prefix) {
            let destination = sanitizedDestination(from: String(trimmed.dropFirst(prefix.count)))
            guard destination.isEmpty == false else { return nil }
            return PendingMapsIntent(
                destination: destination,
                language: .english,
                originalPrompt: prompt
            )
        }

        return nil
    }

    private func travelMode(from prompt: String) -> MapsTravelMode? {
        let normalized = prompt.lowercased()

        if normalized.contains("走路") || normalized.contains("步行") || normalized.contains("walk") || normalized.contains("walking") {
            return .walking
        }

        if normalized.contains("开车") || normalized.contains("驾车") || normalized.contains("drive") || normalized.contains("driving") || normalized.contains("car") {
            return .driving
        }

        return nil
    }

    private func explicitHealthIntent(from prompt: String) -> HealthRouteSession? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let normalized = trimmed.lowercased()
        guard shouldHandoffToHealth(normalized: normalized, prompt: trimmed) else {
            return nil
        }

        let language: HealthConversationLanguage = Self.containsChinese(in: trimmed) ? .chinese : .english
        let topic = healthTopic(normalized: normalized, prompt: trimmed)

        return HealthRouteSession(
            topic: topic,
            language: language,
            originalPrompt: prompt
        )
    }

    private func shouldHandoffToHealth(normalized: String, prompt: String) -> Bool {
        guard containsHealthTopic(normalized: normalized, prompt: prompt) else {
            return false
        }

        if isDirectHealthOpenRequest(normalized: normalized, prompt: prompt) {
            return true
        }

        if containsNonHealthProductContext(normalized: normalized, prompt: prompt) {
            return false
        }

        return isHealthStatusQuery(normalized: normalized, prompt: prompt)
    }

    private func healthTopic(normalized: String, prompt: String) -> HealthFocusedTopic {
        if normalized.contains("ecg") || normalized.contains("electrocardiogram") || prompt.contains("心电") {
            return .ecg
        }

        if normalized.contains("sleep") || normalized.contains("slept") || normalized.contains("bed") || prompt.contains("睡") {
            return .sleep
        }

        if normalized.contains("recovery") || normalized.contains("recover") || normalized.contains("readiness") || prompt.contains("恢复") || prompt.contains("疲劳") {
            return .recovery
        }

        if normalized.contains("step") ||
            normalized.contains("walking") ||
            normalized.contains("walked") ||
            normalized.contains("workout") ||
            normalized.contains("activity") ||
            prompt.contains("步数") ||
            prompt.contains("运动") ||
            prompt.contains("锻炼")
        {
            return .activity
        }

        if normalized.contains("heart rate") ||
            normalized.contains("resting heart") ||
            normalized.contains("pulse") ||
            normalized.contains("bpm") ||
            normalized.contains("hrv") ||
            prompt.contains("心率") ||
            prompt.contains("心跳")
        {
            return .heart
        }

        return .overall
    }

    private func containsHealthTopic(normalized: String, prompt: String) -> Bool {
        let englishTokens = [
            "sleep",
            "slept",
            "recovery",
            "recover",
            "health",
            "wellness",
            "heart",
            "hrv",
            "bpm",
            "pulse",
            "step",
            "steps",
            "workout",
            "activity",
            "ecg",
            "electrocardiogram",
        ]
        let chineseTokens = [
            "健康",
            "睡",
            "恢复",
            "心率",
            "心跳",
            "步数",
            "运动",
            "锻炼",
            "心电",
        ]

        if englishTokens.contains(where: normalized.contains) {
            return true
        }

        return chineseTokens.contains(where: prompt.contains)
    }

    private func containsNonHealthProductContext(normalized: String, prompt: String) -> Bool {
        let englishTokens = [
            "healthkit",
            "permission",
            "privacy",
            "policy",
            "feature",
            "tool",
            "route",
            "page",
            "surface",
            "design",
            "sdk",
            "api",
            "integration",
            "import",
            "export",
            "chat",
        ]
        let chineseTokens = [
            "权限",
            "隐私",
            "设计",
            "页面",
            "入口",
            "工具",
            "路由",
            "功能",
            "接口",
            "导入",
            "导出",
            "聊天",
        ]

        if englishTokens.contains(where: normalized.contains) {
            return true
        }

        return chineseTokens.contains(where: prompt.contains)
    }

    private func isDirectHealthOpenRequest(normalized: String, prompt: String) -> Bool {
        let englishPhrases = [
            "open health",
            "open health page",
            "show health",
            "show me health",
            "take me to health",
            "go to health",
        ]
        let chinesePhrases = [
            "打开健康",
            "打开健康页面",
            "进入健康",
            "去健康页",
            "看健康页",
        ]

        if englishPhrases.contains(where: normalized.contains) {
            return true
        }

        return chinesePhrases.contains(where: prompt.contains)
    }

    private func isHealthStatusQuery(normalized: String, prompt: String) -> Bool {
        let englishPhrases = [
            "how is",
            "how's",
            "how am",
            "what is",
            "what's",
            "did i",
            "am i",
            "show me",
            "check my",
            "review my",
            "analyze my",
            "analyse my",
            "tell me",
            "today",
            "tonight",
            "last night",
            "recent",
            "lately",
            "trend",
            "status",
            "overview",
        ]
        let chinesePhrases = [
            "怎么样",
            "如何",
            "好吗",
            "睡得",
            "情况",
            "状态",
            "趋势",
            "最近",
            "昨晚",
            "今天",
            "看下",
            "看看",
            "查下",
            "查一下",
            "分析",
            "评估",
        ]

        if normalized.contains("?") || prompt.contains("？") {
            return true
        }

        if englishPhrases.contains(where: normalized.contains) {
            return true
        }

        return chinesePhrases.contains(where: prompt.contains)
    }

    private func exactHealthCommand(
        normalized: String,
        prompt: String
    ) -> HealthRouteSession? {
        let englishCommands = ["health", "open health", "health page"]
        let chineseCommands = ["健康", "打开健康", "健康页"]

        guard englishCommands.contains(normalized) || chineseCommands.contains(prompt) else {
            return nil
        }

        let language: HealthConversationLanguage = Self.containsChinese(in: prompt) ? .chinese : .english
        return HealthRouteSession(
            topic: .overall,
            language: language,
            originalPrompt: prompt
        )
    }

    private func isMapsCommand(_ normalized: String, prompt: String) -> Bool {
        let englishCommands = ["map", "maps", "open maps"]
        let chineseCommands = ["地图", "打开地图", "maps"]
        return englishCommands.contains(normalized) || chineseCommands.contains(prompt)
    }

    private func isUserCommand(_ normalized: String, prompt: String) -> Bool {
        let englishCommands = ["user", "profile", "me", "open user"]
        let chineseCommands = ["用户", "个人资料", "设置", "我的"]
        return englishCommands.contains(normalized) || chineseCommands.contains(prompt)
    }

    private func handleTemplateChatChange() {
        if isTemplateChat {
            persistence.remove()
        } else {
            persistIfNeeded()
        }
    }

    private func persistIfNeeded() {
        guard isTemplateChat == false else {
            return
        }
        persistence.save(session)
    }

    private func sanitizedDestination(from raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。！？.!?,，"))
    }

    private static func isGenericMapsPrompt(_ normalized: String, prompt: String) -> Bool {
        let englishKeywords = [
            "apple store",
            "navigate",
            "direction",
            "route",
            "nearby",
            "map",
            "clinic",
            "pharmacy"
        ]
        let chineseKeywords = [
            "地图",
            "路线",
            "导航",
            "附近",
            "诊所",
            "药店",
            "超市"
        ]

        if englishKeywords.contains(where: normalized.contains) {
            return true
        }

        return chineseKeywords.contains(where: prompt.contains)
    }

    private static func containsChinese(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00 ... 0x9FFF).contains(Int(scalar.value))
        }
    }
}
