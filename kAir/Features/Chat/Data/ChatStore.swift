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
    var selectedModeID = "ask"
    var contextSummary = "One thread across Health, AI, Maps, and Store"
    var suggestedPrompts: [String] = [
        "Connect Apple Health",
        "我想去超市",
        "Which model is active?",
        "What can kAir do for me?"
    ]

    /// Current Recommended Next slate. Populated from the
    /// `RecommendationProvider` at init. The chat home reads this
    /// directly; an empty array means the rail is absent per
    /// mixed-recommendation-rail-visual-v1 §3.
    var recommendedMatches: [MatchingObject] = []

    /// Recommendations the user marked `.alreadyDone`.
    ///
    /// `.alreadyDone` elevates to `.completion` per
    /// `Docs/design/post-return-and-continuation-ux-v1.md` §1.1 row C
    /// and `Contracts/UX/feedback-runtime-v1.md` §4.1 — it exits the
    /// negative-feedback flow and enters the post-return / completion
    /// flow. This log is the minimum hand-off in Main A: the
    /// recommendation id is recorded here so the (future) post-return
    /// continuation runtime can consume the elevation. It is NOT a
    /// typed `ChatContinuationEvent` emit; that lives in
    /// continuation-runtime wiring (separate work line).
    private(set) var completedRecommendations: [String] = []

    /// Last `feedbackRuntime.emit(_:)` task. Tests `await` it to wait
    /// for the fire-and-forget emission to complete before asserting
    /// on the runtime spy. Production code does NOT consume this.
    private(set) var pendingFeedbackEmit: Task<Void, Never>?

    private let recommendationProvider: RecommendationProvider
    private let feedbackRuntime: FeedbackRuntime
    private var lastRefreshDate: Date?
    private var supportsHealthData = true
    private var pendingMapsIntent: PendingMapsIntent?
    private var resolvedMapsSession: MapsRouteSession?

    init(
        recommendationProvider: RecommendationProvider = StubRecommendationProvider(),
        feedbackRuntime: FeedbackRuntime = NoOpFeedbackRuntime()
    ) {
        self.recommendationProvider = recommendationProvider
        self.feedbackRuntime = feedbackRuntime
        self.recommendedMatches = recommendationProvider.recommendedMatches()
    }

    /// Re-fetches the slate from the recommendation provider.
    ///
    /// Per `Contracts/UX/feedback-runtime-v1.md` §6.2, this fires
    /// exactly once per dismissal for each of the four negatives.
    /// For `.alreadyDone`, the elevation hands off to post-return,
    /// which owns refresh; this contract's runtime MUST NOT call
    /// refresh from that path.
    ///
    /// Note: the current `StubRecommendationProvider` returns a fixed
    /// slate and does NOT respect a suppression log. After a dismiss,
    /// calling refresh will re-introduce the dismissed card. Closing
    /// this gap requires a real provider — separate work line, per
    /// the feedback-runtime-v1.md §13 implementation gap. Main A's
    /// scope is to wire the refresh CALL; provider-side suppression
    /// is out of scope.
    func refreshRecommendedMatches() {
        self.recommendedMatches = recommendationProvider.recommendedMatches()
    }

    /// Removes the given recommendation from the rail (same-frame per
    /// V3 §6.1) and emits a typed `FeedbackEvent` via the injected
    /// `FeedbackRuntime`.
    ///
    /// Behavior per `Contracts/UX/feedback-runtime-v1.md`:
    ///   - All 5 feedback kinds: construct + validate + emit a
    ///     `FeedbackEvent` (§3, §6.3 step 1–3); remove the card from
    ///     the slate (§6.3 step 4).
    ///   - Four negatives (`.dismiss`, `.notInterested`,
    ///     `.lessLikeThis`, `.notNow`): call
    ///     `refreshRecommendedMatches()` exactly once after removal
    ///     (§6.2).
    ///   - `.alreadyDone`: do NOT call refresh (§4.1, §6.2). Append
    ///     the recommendation id to `completedRecommendations` so the
    ///     (future) post-return continuation runtime can consume the
    ///     elevation per `post-return-and-continuation-ux-v1.md` §1.1
    ///     row C.
    ///   - All 5 kinds: write nothing to `session.messages`
    ///     (§7.1 + behavior §3.4).
    ///
    /// Validation: if the constructed envelope fails
    /// `FeedbackEventValidator` (per §8), this method is a silent
    /// no-op — the card is NOT removed and no event is emitted.
    /// Validation failure is a programming error, not a user-visible
    /// branch.
    ///
    /// Projection choice (§9.2): option (a) — the typed
    /// `FeedbackEvent` is the sole source of truth. No
    /// `MatchingBehaviorEvent`-shaped record is constructed from this
    /// path.
    func dismissRecommendation(
        _ object: MatchingObject,
        feedback: MatchingFeedbackKind
    ) {
        let event = FeedbackEvent(
            id: "feedback-\(object.id)-\(UUID().uuidString)",
            recommendationId: object.id,
            feedbackKind: feedback,
            surface: nil,
            createdAt: Date()
        )

        guard FeedbackEventValidator.validate(event).isEmpty else {
            // Programming error per §8; abort silently. Card stays
            // on screen; emit does not fire.
            return
        }

        // Same-frame removal per V3 §6.1 / §6.3 step 4. Applies to
        // all 5 kinds.
        recommendedMatches.removeAll { $0.id == object.id }

        // Fire-and-forget emit. NoOp by default; production runtimes
        // record to scorer / telemetry sinks. The Task is exposed
        // via `pendingFeedbackEmit` so tests can await it before
        // asserting on a spy.
        let runtime = feedbackRuntime
        pendingFeedbackEmit = Task { @MainActor in
            try? await runtime.emit(event)
        }

        switch feedback {
        case .alreadyDone:
            // Completion / post-return handoff per §4.1 + post-return
            // §1.1 row C. Do NOT call refresh; record the elevation
            // for the (future) post-return runtime.
            completedRecommendations.append(object.id)

        case .dismiss, .notInterested, .lessLikeThis, .notNow:
            // Four negatives: refresh once after removal per §6.2.
            refreshRecommendedMatches()
        }
    }

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

    func consumeResolvedMapsSession() -> MapsRouteSession? {
        let session = resolvedMapsSession
        resolvedMapsSession = nil
        return session
    }

    func route(for prompt: String) -> AppSection? {
        if pendingMapsIntent != nil, travelMode(from: prompt) != nil {
            return .maps
        }

        if explicitMapsIntent(from: prompt) != nil {
            return nil
        }

        let normalized = prompt.lowercased()

        if Self.isGenericMapsPrompt(normalized, prompt: prompt) {
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

        if let mapsMessage = handleMapsFlow(prompt: prompt) {
            session.messages.append(mapsMessage)
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

        if isGenericMapsPrompt(normalized, prompt: prompt) {
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
            ? "kAir is already chat-first. You can explore AI, Maps, and Store now, and attach Apple Health later when you want grounded health guidance."
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

        return [healthSnapshotResult(for: dashboard)]
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
