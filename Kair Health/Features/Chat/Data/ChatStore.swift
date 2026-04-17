//
//  ChatStore.swift
//  Kair Health
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
    var selectedModeID = "ask"
    var contextSummary = "One thread across Health, AI, Maps, and Store"
    var suggestedPrompts: [String] = [
        "Connect Apple Health",
        "I want to go to Apple Store",
        "Which model is active?",
        "What can kAir do for me?"
    ]

    private var lastRefreshDate: Date?
    private var supportsHealthData = true

    func bootstrap(with dashboard: HealthDashboard) {
        supportsHealthData = true
        contextSummary = "\(dashboard.hero.band) · Apple Health \(dashboard.generatedAt.formatted(.dateTime.hour().minute())) · local-first"
        suggestedPrompts = Self.suggestedPrompts(for: dashboard)

        guard lastRefreshDate != dashboard.generatedAt else { return }

        if session.messages.isEmpty {
            session.messages = [
                .assistant(
                    text: Self.welcomeMessage(for: dashboard),
                    timestamp: dashboard.generatedAt,
                    tags: ["All-in-one", dashboard.hero.band],
                    toolResults: [Self.healthSnapshotResult(for: dashboard)]
                ),
            ]
        } else {
            session.messages.append(
                .system(
                    text: "Apple Health refreshed. The leading focus is \(Self.leadingInsight(in: dashboard)?.title.lowercased() ?? "recent health trends").",
                    timestamp: dashboard.generatedAt,
                    tags: ["Updated"]
                )
            )
        }

        lastRefreshDate = dashboard.generatedAt
    }

    func bootstrapWithoutDashboard(supportsHealthData: Bool) {
        self.supportsHealthData = supportsHealthData
        contextSummary = supportsHealthData
            ? "Chat-first shell · attach Apple Health when you want grounded health answers"
            : "HealthKit unavailable · AI, Maps, and Store remain available"
        suggestedPrompts = Self.fallbackSuggestedPrompts(supportsHealthData: supportsHealthData)

        guard session.messages.isEmpty else { return }

        session.messages = [
            .assistant(
                text: Self.welcomeMessageWithoutDashboard(supportsHealthData: supportsHealthData),
                tags: ["Chat-first", "Local-first"],
                toolResults: [Self.healthAccessResult(supportsHealthData: supportsHealthData)]
            ),
        ]
    }

    func selectMode(_ mode: ComposerMode) {
        selectedModeID = mode.id
    }

    func sendDraft(using dashboard: HealthDashboard?) {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        draft = ""
        submit(prompt: trimmed, using: dashboard)
    }

    func submitPrompt(_ prompt: String, using dashboard: HealthDashboard?) {
        submit(prompt: prompt, using: dashboard)
    }

    func recordHandoff(to section: AppSection) {
        session.messages.append(
            .system(
                text: "Opened \(section.title) as a focused surface while keeping this thread intact.",
                tags: ["\(section.title) handoff"]
            )
        )
    }

    func attachReference(_ title: String, detail: String) {
        session.messages.append(
            .system(
                text: "\(title) attached. \(detail)",
                tags: ["Reference"]
            )
        )
    }

    func route(for prompt: String) -> AppSection? {
        let normalized = prompt.lowercased()

        if normalized.contains("apple store") ||
            normalized.contains("go to") ||
            normalized.contains("navigate") ||
            normalized.contains("direction") ||
            normalized.contains("route") ||
            normalized.contains("nearby") ||
            normalized.contains("map") ||
            normalized.contains("clinic") ||
            normalized.contains("pharmacy")
        {
            return .maps
        }

        if normalized.contains("buy") ||
            normalized.contains("shop") ||
            normalized.contains("order") ||
            normalized.contains("supplement") ||
            normalized.contains("device") ||
            normalized.contains("bundle")
        {
            return .store
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return .ai
        }

        if normalized.contains("sleep") ||
            normalized.contains("recovery") ||
            normalized.contains("health") ||
            normalized.contains("heart") ||
            normalized.contains("hrv") ||
            normalized.contains("ecg")
        {
            return .health
        }

        return nil
    }

    private func submit(prompt: String, using dashboard: HealthDashboard?) {
        session.messages.append(
            .user(
                text: prompt,
                tags: selectedModeID == "ask" ? [] : [selectedMode.title]
            )
        )
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
    }

    private var selectedMode: ComposerMode {
        modes.first(where: { $0.id == selectedModeID }) ?? modes[0]
    }

    private static func suggestedPrompts(for dashboard: HealthDashboard) -> [String] {
        [
            "What changed most in my health today?",
            "Which nearby place fits recovery best?",
            "Which model should answer a health question?",
            "I want to go to Apple Store",
            "What should I buy for sleep and recovery?"
        ]
    }

    private static func fallbackSuggestedPrompts(supportsHealthData: Bool) -> [String] {
        if supportsHealthData {
            [
                "Connect Apple Health",
                "I want to go to Apple Store",
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
        "You are in kAir. I can read your local Apple Health snapshot, explain it in plain language, route you into AI, prep nearby places, and stage store suggestions without breaking the thread. \(dashboard.hero.summary)"
    }

    private static func welcomeMessageWithoutDashboard(supportsHealthData: Bool) -> String {
        if supportsHealthData {
            return "You are in kAir. Chat is already live, and Health can be attached when you want grounded Apple Health answers. Until then I can still route AI, Maps, and Store from this same thread."
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

        if normalized.contains("nearby") || normalized.contains("map") || normalized.contains("clinic") || normalized.contains("pharmacy") || normalized.contains("route") {
            return "Maps should stay quiet and utilitarian inside kAir: nearby clinics, pharmacies, gyms, and walking routes, surfaced as task-ready places instead of a noisy standalone map first."
        }

        if normalized.contains("model") || normalized.contains("ai") || modeID == "route" {
            if let prediction = dashboard.predictions.first {
                return "The active AI posture is local-first. I would keep health explanations grounded in your Apple Health snapshot, use a compact planner to decide which surface to open next, and reserve specialized models for \(prediction.title.lowercased()) or other deep reads when needed."
            }
            return "The AI layer is designed as a routing surface: one general model for conversation, one health explainer, and one planner for when to open Maps, Store, or a deeper Health view."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("supplement") || normalized.contains("device") || modeID == "shop" {
            return "Store should feel curated, not loud. I would prioritize sleep and recovery tools first, then wearables, then lightweight nutrition suggestions, all anchored to what your health data actually suggests is worth watching."
        }

        if normalized.contains("privacy") || normalized.contains("local") {
            return "kAir reads Apple Health through HealthKit on-device. The design keeps health, AI, maps, and store inside one shell, but the health context stays local-first and visible."
        }

        return "Right now your overall health status is \(dashboard.hero.band.lowercased()), and the clearest focus is \(leadingInsight(in: dashboard)?.title.lowercased() ?? "recent trends"). If you want, I can unpack the data itself, open a nearby route, explain the AI stack, or stage store recommendations."
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

        if normalized.contains("map") || normalized.contains("route") || normalized.contains("go to") || normalized.contains("nearby") || modeID == "route" {
            return "Maps can still be invoked immediately from chat. I will preserve this thread, then hand off into a focused navigation surface."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("shop") || modeID == "shop" {
            return "Store can still open from the conversation, but curation will be broader until Apple Health is attached."
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return "The AI layer is already live. One orchestrator handles the thread, then opens deeper surfaces only when the task needs them."
        }

        return supportsHealthData
            ? "kAir is already chat-first. You can explore AI, Maps, and Store now, and attach Apple Health later when you want grounded health guidance."
            : "kAir is already chat-first. AI, Maps, and Store are available now, but Health grounding is unavailable on this device."
    }

    private static func replyTags(for prompt: String, modeID: String, dashboard: HealthDashboard) -> [String] {
        let normalized = prompt.lowercased()
        var tags = ["Local-first"]

        if modeID != "ask" {
            tags.append(modeID.capitalized)
        }

        if normalized.contains("map") || normalized.contains("nearby") || normalized.contains("clinic") {
            tags.append("Maps")
        } else if normalized.contains("store") || normalized.contains("buy") || normalized.contains("supplement") {
            tags.append("Store")
        } else if normalized.contains("model") || normalized.contains("ai") {
            tags.append("AI")
        } else {
            tags.append("Health")
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
        } else {
            tags.append(supportsHealthData ? "Connect Health" : "Health unavailable")
        }

        return tags
    }

    private static func toolResults(for prompt: String, dashboard: HealthDashboard) -> [ConversationToolResult] {
        let normalized = prompt.lowercased()

        if normalized.contains("map") || normalized.contains("nearby") || normalized.contains("clinic") || normalized.contains("pharmacy") || normalized.contains("route") {
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

        return [healthSnapshotResult(for: dashboard)]
    }

    private static func toolResultsWithoutDashboard(
        for prompt: String,
        supportsHealthData: Bool
    ) -> [ConversationToolResult] {
        let normalized = prompt.lowercased()

        if normalized.contains("map") || normalized.contains("nearby") || normalized.contains("clinic") || normalized.contains("pharmacy") || normalized.contains("route") {
            return [mapsResult()]
        }

        if normalized.contains("model") || normalized.contains("ai") {
            return [ungroundedAIResult()]
        }

        if normalized.contains("store") || normalized.contains("buy") || normalized.contains("shop") {
            return [storeResult()]
        }

        return [healthAccessResult(supportsHealthData: supportsHealthData)]
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

    private static func leadingInsight(in dashboard: HealthDashboard) -> InsightCard? {
        dashboard.insights.max(by: { $0.score < $1.score })
    }
}
