//
//  ChatStore.swift
//  kAir
//
//  Local orchestration for the kAir conversation surface.
//

import Foundation
import Observation

enum ChatSearchAvailabilityState: Equatable, Sendable {
    case notInBuild
    case registeredUnavailable
    case available

    init(webSearchAvailability: Bool?) {
        switch webSearchAvailability {
        case .some(true):
            self = .available
        case .some(false):
            self = .registeredUnavailable
        case nil:
            self = .notInBuild
        }
    }

    var statusLine: String {
        switch self {
        case .notInBuild:
            return "Search not installed"
        case .registeredUnavailable:
            return "Search reserved but unavailable"
        case .available:
            return "Search available"
        }
    }
}

struct ChatSearchAvailabilityDisplay: Equatable, Sendable {
    enum Tone: String, Equatable, Sendable {
        case neutral
        case warning
        case positive
    }

    let isVisible: Bool
    let systemImage: String
    let tone: Tone
    let title: String
    let statusLine: String
    let accessibilityLabel: String

    init(
        isVisible: Bool,
        systemImage: String,
        tone: Tone,
        title: String,
        statusLine: String,
        accessibilityLabel: String
    ) {
        self.isVisible = isVisible
        self.systemImage = systemImage
        self.tone = tone
        self.title = title
        self.statusLine = statusLine
        self.accessibilityLabel = accessibilityLabel
    }

    init(state: ChatSearchAvailabilityState) {
        switch state {
        case .notInBuild:
            self.init(
                isVisible: false,
                systemImage: "magnifyingglass",
                tone: .neutral,
                title: "Search not installed",
                statusLine: "Search not installed",
                accessibilityLabel: "Search is not installed in this build."
            )
        case .registeredUnavailable:
            self.init(
                isVisible: true,
                systemImage: "magnifyingglass.circle",
                tone: .warning,
                title: "Search unavailable",
                statusLine: "Search reserved but unavailable",
                accessibilityLabel: "Search is reserved but unavailable."
            )
        case .available:
            self.init(
                isVisible: true,
                systemImage: "magnifyingglass.circle.fill",
                tone: .positive,
                title: "Search available",
                statusLine: "Search available",
                accessibilityLabel: "Search is available."
            )
        }
    }
}

@MainActor
@Observable
final class ChatStore {
    let modes: [ComposerMode] = [
        ComposerMode(id: "ask", title: "Ask", systemImage: "bubble.left"),
        ComposerMode(id: "coach", title: "Coach", systemImage: "waveform.path.ecg"),
        ComposerMode(id: "route", title: "Route", systemImage: "arrow.triangle.branch"),
        ComposerMode(id: "shop", title: "Shop", systemImage: "bag"),
    ]

    static let allAccessories: [ComposerAccessory] = [
        ComposerAccessory(id: "health", title: "Health", systemImage: "heart.text.square"),
        ComposerAccessory(id: "ai", title: "AI", systemImage: "cpu"),
        ComposerAccessory(id: "maps", title: "Maps", systemImage: "map"),
        ComposerAccessory(id: "store", title: "Store", systemImage: "bag"),
    ]

    /// Composer capability chips, filtered to the surfaces enabled for this
    /// build (`AppBootstrap.enabledSurfaces`). Each chip id maps to its
    /// like-named `AppSection`. Defaults to all surfaces.
    var accessories: [ComposerAccessory] {
        Self.allAccessories.filter { accessory in
            AppSection(rawValue: accessory.id).map(enabledSurfaces.contains) ?? true
        }
    }

    var session = ChatSession(title: "kAir", messages: [])
    var draft = ""
    var selectedModeID = "ask"
    var contextSummary = "One private thread, on your device"
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

    /// Last `feedbackRuntime.emit(_:)` task. Tests `await` it to wait
    /// for the fire-and-forget emission to complete before asserting
    /// on the runtime spy. Production code does NOT consume this.
    private(set) var pendingFeedbackEmit: Task<Void, Never>?

    /// Last `telemetryEmitter.emit(_:_:)` task fired from the prompt
    /// commit path. Mirrors the `pendingFeedbackEmit` pattern: tests
    /// `await` this to wait for the fire-and-forget telemetry emit
    /// to complete before asserting on a sink. Production code does
    /// NOT consume this.
    ///
    /// Per Main B scope, this handle is populated only by
    /// `chat.prompt.submit`. Future emit sites (rail, surface,
    /// continuation, feedback) will land their own handles when they
    /// wire up.
    private(set) var pendingTelemetryEmit: Task<Void, Never>?

    /// Last `capabilityRegistry.availabilitySnapshot()` task. Tests
    /// `await` it to wait for the fire-and-forget snapshot to land
    /// in `capabilityAvailability` before asserting. Production code
    /// does NOT consume this.
    private(set) var pendingCapabilityRefresh: Task<Void, Never>?

    /// The in-flight on-device reply regeneration (B6), if any. Tests await it.
    private(set) var pendingReplyGeneration: Task<Void, Never>?

    /// Latest `availabilitySnapshot()` from the capability registry.
    /// Empty until the first refresh resolves; afterwards maps each
    /// registered `CapabilityKind` to its current `isAvailable()`
    /// value per `Contracts/capability-registry-and-adapter-contract-v1.md`
    /// §7.3.
    ///
    /// Main C scope: this property is populated by a real call into
    /// the registry but is NOT yet consumed by any view. The chat UI
    /// keeps its current behavior. Downstream consumers (suggested
    /// prompt filtering, intent routing) are out of Main C scope and
    /// will land via separate work lines.
    private(set) var capabilityAvailability: [CapabilityKind: Bool] = [:]

    private let recommendationProvider: RecommendationProvider
    private let providerStatusProvider: ProviderStatusProviding?
    private let feedbackRuntime: FeedbackRuntime
    private let completedRecommendationHandoff: CompletedRecommendationHandoff
    private let telemetryEmitter: TelemetryEmitter
    private let identifierFactory: TelemetryIdentifierFactory
    private let capabilityRegistry: CapabilityRegistry
    private let textGenerator: (any KAirTextGenerator)?

    /// Stable `thread_id` for this chat session. Issued exactly once
    /// at construction via `identifierFactory.makeThreadID()` per
    /// `Contracts/telemetry-contract-v1.md` §3 (issuer = the chat
    /// session manager). Reused on every emission for the lifetime
    /// of this `ChatStore` instance.
    private let threadID: ThreadID

    /// Public accessor for the chat's `thread_id`. Exposed for the
    /// Main D.1 continuation-telemetry emit, which runs in
    /// `AppBootstrap.recordSurfaceReturn(_:)` and needs to populate
    /// the §5.2 propagation matrix without holding chat-store
    /// internals. The value is `let` underneath; consumers cannot
    /// mutate it.
    var telemetryThreadID: ThreadID { threadID }

    /// Last `TraceID` issued by `emitChatPromptSubmit()` for this
    /// chat session, or `nil` if no prompt has been submitted yet.
    ///
    /// Per `Contracts/telemetry-contract-v1.md` §3, the `trace_id`
    /// is "issued by chat home... at the moment a user prompt is
    /// committed." Downstream events that occur in the same user
    /// request lifecycle (rail, surface, continuation) MUST carry
    /// the SAME `trace_id`. Main D.1 wires the first non-chat
    /// downstream consumer: the continuation-telemetry emit reads
    /// this value at surface-return time.
    ///
    /// `nil` is a valid state — a surface might be opened before
    /// any prompt is submitted (e.g., the user taps a section
    /// directly). The continuation-telemetry emit treats a `nil`
    /// `trace_id` as a missing-required-id programming error per
    /// §5.2 and silently skips the emit.
    private(set) var lastIssuedTraceID: TraceID?

    private var lastRefreshDate: Date?
    private var supportsHealthData = true
    private var pendingMapsIntent: PendingMapsIntent?
    private var resolvedMapsSession: MapsRouteSession?
    private let enabledSurfaces: Set<AppSection>

    init(
        recommendationProvider: RecommendationProvider? = nil,
        providerStatusProvider: ProviderStatusProviding? = nil,
        feedbackRuntime: FeedbackRuntime? = nil,
        completedRecommendationHandoff: CompletedRecommendationHandoff? = nil,
        telemetryEmitter: TelemetryEmitter? = nil,
        identifierFactory: TelemetryIdentifierFactory? = nil,
        capabilityRegistry: CapabilityRegistry? = nil,
        textGenerator: (any KAirTextGenerator)? = nil,
        enabledSurfaces: Set<AppSection> = Set(AppSection.allCases)
    ) {
        let recommendationProvider = recommendationProvider ?? StubRecommendationProvider()
        let identifierFactory = identifierFactory ?? UUIDTelemetryIdentifierFactory()

        self.recommendationProvider = recommendationProvider
        self.providerStatusProvider = providerStatusProvider
            ?? (recommendationProvider as? ProviderStatusProviding)
        self.feedbackRuntime = feedbackRuntime ?? NoOpFeedbackRuntime()
        self.completedRecommendationHandoff = completedRecommendationHandoff
            ?? NoOpCompletedRecommendationHandoff()
        self.telemetryEmitter = telemetryEmitter ?? NoOpTelemetryEmitter()
        self.identifierFactory = identifierFactory
        self.capabilityRegistry = capabilityRegistry
            ?? DefaultCapabilityRegistry.makeWithShippedStubs()
        self.textGenerator = textGenerator
        self.enabledSurfaces = enabledSurfaces
        self.threadID = identifierFactory.makeThreadID()
        self.recommendedMatches = recommendationProvider.recommendedMatches()

        // Main C: real consumer of the capability registry. Fire a
        // one-shot availability snapshot at construction so
        // `capabilityAvailability` reflects the registered §3.1
        // shipped kinds (or whatever the injected registry exposes).
        // Result lands when the task completes; tests `await` it via
        // `pendingCapabilityRefresh`.
        refreshCapabilityAvailability()
    }

    /// Re-fetches `capabilityRegistry.availabilitySnapshot()` and
    /// stores the result on `capabilityAvailability`.
    ///
    /// Per `Contracts/capability-registry-and-adapter-contract-v1.md`
    /// §7.3, the snapshot is a point-in-time map from each
    /// registered kind to its current `isAvailable()` value. v1
    /// adapters MUST keep `isAvailable()` cheap (§6) so this refresh
    /// is safe to call at construction and on demand.
    ///
    /// Main C scope: callable from production code (it runs at init)
    /// AND from tests (which call it explicitly to verify the wiring
    /// is real). Downstream auto-refresh hooks (e.g. on app
    /// foreground, on permission change) are NOT wired here — those
    /// belong to the runtime that owns the underlying availability
    /// signal, not to chat home.
    func refreshCapabilityAvailability() {
        let registry = capabilityRegistry
        pendingCapabilityRefresh = Task { @MainActor [weak self] in
            let snapshot = await registry.availabilitySnapshot()
            self?.capabilityAvailability = snapshot
        }
    }

    var searchAvailabilityState: ChatSearchAvailabilityState {
        ChatSearchAvailabilityState(
            webSearchAvailability: capabilityAvailability[.webSearch]
        )
    }

    var searchAvailabilityDisplay: ChatSearchAvailabilityDisplay {
        ChatSearchAvailabilityDisplay(state: searchAvailabilityState)
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

    /// Optional provider-status side channel. The rail still consumes only
    /// `recommendedMatches`; providers that do not opt into
    /// `ProviderStatusProviding` return nil here so default fixtures do not
    /// invent fake provider/cost/freshness badges.
    func providerStatusPresentation(
        for recommendationID: String
    ) -> ProviderStatusPresentation? {
        guard recommendedMatches.contains(where: { $0.id == recommendationID }) else {
            return nil
        }
        return providerStatusProvider?.providerStatusPresentation(for: recommendationID)
    }

    // MARK: - Recommendation accept / dismiss

    /// V1 step 2 (chat-home §3.5): the explicit accept bridge for a
    /// Recommended Next card. Distinct from `dismissRecommendation` — it
    /// emits **no** `FeedbackEvent`, no toast, no banner.
    ///
    /// - Existence check: an object not in `recommendedMatches` is a no-op
    ///   (`.unknown`); nothing is removed or written.
    /// - Removes **only** the accepted target; siblings are preserved.
    /// - Writes the target's `activationPrompt` into the thread as a user
    ///   message. This is NOT the composer submit path, so it does not stage
    ///   the §9 `DirectSubmitGate` and does not run `route(for:)`.
    /// - Clears any pending raw Maps route context before returning a route,
    ///   so recommendation accept cannot consume a stale composer Maps
    ///   session.
    /// - Returns `.route(section)` when `preferredSection` maps to a
    ///   closed-catalog surface, else `.threadOnly` (the thread write is the
    ///   only effect — the caller must not guess a surface to open).
    func prepareRecommendationForAccept(
        _ object: MatchingObject
    ) -> RecommendationAcceptResult {
        guard let index = recommendedMatches.firstIndex(where: { $0.id == object.id }) else {
            return .unknown
        }
        let target = recommendedMatches.remove(at: index)
        clearPendingMapsRouteContext()

        if target.activationPrompt.isEmpty == false {
            session.messages.append(.user(text: target.activationPrompt))
        }

        if let surface = target.preferredSection,
           let section = AppSection(rawValue: surface.rawValue) {
            return .route(section)
        }
        return .threadOnly
    }

    /// Outcome of `prepareRecommendationForAccept(_:)`.
    enum RecommendationAcceptResult: Equatable {
        /// The object was not in `recommendedMatches`; nothing changed.
        case unknown
        /// Accepted (target removed + activation prompt written); the caller
        /// should open this surface.
        case route(AppSection)
        /// Accepted (target removed + activation prompt written) but the route
        /// is not resolvable — the thread write is the only effect.
        case threadOnly
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
    ///   - `.alreadyDone`: do NOT call refresh (§4.1, §6.2). Hand the
    ///     recommendation off to the injected
    ///     `CompletedRecommendationHandoff` so the (future) post-return
    ///     continuation runtime can consume the elevation per
    ///     `post-return-and-continuation-ux-v1.md` §1.1 row C. The
    ///     handoff MUST NOT cause a transcript receipt or telemetry
    ///     emit — see `CompletedRecommendationHandoff.swift` for the
    ///     boundary.
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
            // §1.1 row C. Do NOT call refresh; hand off the elevation
            // to the injected handoff so the (future) post-return
            // runtime can consume it. The handoff is composed at the
            // app's composition root (`AppBootstrap`); `ChatStore`
            // does NOT decide its concrete type.
            completedRecommendationHandoff.record(object)

        case .dismiss, .notInterested, .lessLikeThis, .notNow:
            // Four negatives: refresh once after removal per §6.2.
            refreshRecommendedMatches()
        }
    }

    private func clearPendingMapsRouteContext() {
        pendingMapsIntent = nil
        resolvedMapsSession = nil
    }

    func bootstrap(with dashboard: HealthDashboard) {
        supportsHealthData = true
        contextSummary = "\(dashboard.hero.band) · Apple Health \(dashboard.generatedAt.formatted(.dateTime.hour().minute())) · local-first"
        suggestedPrompts = offersCapabilitySurfaces
            ? Self.suggestedPrompts(for: dashboard)
            : Self.healthFirstSuggestedPrompts(supportsHealthData: true)

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
            : "HealthKit unavailable · chat stays available on-device"
        suggestedPrompts = offersCapabilitySurfaces
            ? Self.fallbackSuggestedPrompts(supportsHealthData: supportsHealthData)
            : Self.healthFirstSuggestedPrompts(supportsHealthData: supportsHealthData)

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

    /// Main D transcript projection per
    /// `Contracts/UX/continuation-runtime-v1.md` §8.1 (option b).
    ///
    /// Appends exactly one `.assistant` `ConversationMessage` carrying
    /// the typed `continuationEvent` for `renderEligible == true`
    /// events. For `renderEligible == false` events (`.dismiss` /
    /// `.acceptNoEntry`), appends NOTHING — those are silent records.
    ///
    /// The assistant message's text uses the event's summary text so
    /// the existing transcript renderer has fallback content while
    /// `ContinuationBlockRenderer` reads the typed payload.
    ///
    /// Boundary:
    ///   - This method does NOT emit telemetry. The runtime emit
    ///     fires from `AppBootstrap.recordSurfaceReturn(_:)` and is
    ///     parallel to this projection per §8.3.
    ///   - This method does NOT re-validate the event. Validation
    ///     belongs to the chokepoint in `recordSurfaceReturn(_:)`.
    func recordContinuation(_ event: ChatContinuationEvent) {
        guard event.renderEligible else {
            // Silent path per §6 + §8.1: zero `ConversationMessage`
            // emissions. The event is recorded by the runtime for
            // observability only.
            return
        }

        let text = event.summary?.summary ?? "Returned to chat."
        session.messages.append(
            .assistant(
                text: text,
                continuationEvent: event
            )
        )
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
        guard let candidate = rawRoute(for: prompt) else { return nil }
        return enabledSurfaces.contains(candidate) ? candidate : nil
    }

    private func rawRoute(for prompt: String) -> AppSection? {
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
            normalized.contains("store") ||
            normalized.contains("order") ||
            normalized.contains("supplement") ||
            normalized.contains("device") ||
            normalized.contains("bundle")
        {
            return .store
        }

        // Word-boundary match so "explain", "kair", "again", "air" don't
        // misroute to AI on the bare `contains("ai")` substring.
        let words = Set(normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if words.contains("model") || words.contains("ai") || normalized.contains("a.i.") {
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
        // Main B: telemetry minimum real emission.
        //
        // Per `Contracts/telemetry-contract-v1.md` §4.1, the composer
        // fires `chat.prompt.submit` exactly once per committed
        // prompt. This is the FIRST real telemetry emit in kAir; the
        // §5.2 propagation matrix requires `trace_id` and `thread_id`
        // and forbids the other five identifier kinds.
        //
        // Identifier issuance is single-sourced through
        // `TelemetryIdentifierFactory` (Main B reviewer invariant
        // #1): `thread_id` was captured once at init; `trace_id` is
        // freshly issued here per §3 (one trace = one user request
        // lifecycle).
        //
        // Validation parallels the FeedbackRuntime path: a propagation
        // matrix violation is a programming error, NOT a user-visible
        // branch. On violation, the emit is silently skipped; the
        // user prompt still commits.
        emitChatPromptSubmit()

        session.messages.append(
            .user(
                text: prompt,
                tags: selectedModeID == "ask" ? [] : [selectedMode.title]
            )
        )

        if enabledSurfaces.contains(.maps), let mapsMessage = handleMapsFlow(prompt: prompt) {
            session.messages.append(mapsMessage)
            return
        }

        let baselineText: String
        let replyTags: [String]
        let replyToolResults: [ConversationToolResult]
        if let withheld = withheldSurfaceContent(for: prompt) {
            // v1 capability gate: a prompt aimed at a withheld surface
            // (Maps/Store/AI) must never surface that surface's copy or a
            // placeholder tool card. Answer on-device, with no surface card.
            baselineText = withheld.text
            replyTags = withheld.tags
            replyToolResults = []
        } else {
            baselineText = dashboard.map {
                Self.reply(to: prompt, modeID: selectedModeID, dashboard: $0)
            } ?? Self.replyWithoutDashboard(
                to: prompt,
                modeID: selectedModeID,
                supportsHealthData: supportsHealthData
            )
            replyTags = dashboard.map {
                Self.replyTags(for: prompt, modeID: selectedModeID, dashboard: $0)
            } ?? Self.replyTagsWithoutDashboard(
                for: prompt,
                modeID: selectedModeID,
                supportsHealthData: supportsHealthData
            )
            replyToolResults = dashboard.map {
                Self.toolResults(for: prompt, dashboard: $0)
            } ?? Self.toolResultsWithoutDashboard(
                for: prompt,
                supportsHealthData: supportsHealthData
            )
        }

        let assistantMessage = ConversationMessage.assistant(
            text: baselineText,
            tags: replyTags,
            toolResults: replyToolResults
        )
        session.messages.append(assistantMessage)

        // On-device AI (B6): when a generator is injected, regenerate the reply
        // text on-device (Apple Foundation Models, else deterministic fallback)
        // and replace the baseline in place. The static baseline keeps the
        // non-generator path — and all existing tests — unchanged.
        if let textGenerator {
            let request = KAirGenerationRequest(
                systemInstructions: Self.assistantInstructions,
                prompt: prompt
            )
            let messageID = assistantMessage.id
            // Cancel any still-running prior generation before replacing the
            // handle (each Task targets its own message id, so this only frees
            // the superseded request — `try?` below already swallows the cancel).
            pendingReplyGeneration?.cancel()
            pendingReplyGeneration = Task { @MainActor [weak self] in
                guard let generated = try? await textGenerator.generate(request),
                      generated.isEmpty == false else { return }
                self?.replaceMessageText(id: messageID, with: generated)
            }
        }
    }

    /// System prompt for on-device chat generation — grounded + non-diagnostic
    /// (PrivacyGuard `.modelOutputsMustRemainNonDiagnostic`).
    static let assistantInstructions = """
    You are kAir, a concise local-first assistant. Answer helpfully in 1–3 \
    sentences. You are not a medical professional: never diagnose, prescribe, or \
    claim medical certainty; for health topics, summarize gently and suggest \
    consulting a clinician for any concern. Point to the app's surfaces (health \
    overview, maps, store) when relevant.
    """

    /// Replace an existing message's text in place (same id / tags / results).
    private func replaceMessageText(id: String, with text: String) {
        guard let index = session.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        let existing = session.messages[index]
        session.messages[index] = ConversationMessage(
            id: existing.id,
            role: existing.role,
            author: existing.author,
            text: text,
            timestamp: existing.timestamp,
            tags: existing.tags,
            toolResults: existing.toolResults,
            continuationEvent: existing.continuationEvent
        )
    }

    private var selectedMode: ComposerMode {
        modes.first(where: { $0.id == selectedModeID }) ?? modes[0]
    }

    /// Emits exactly one `TelemetryEvent.chatPromptSubmit` per call
    /// per `Contracts/telemetry-contract-v1.md` §4.1.
    ///
    /// Payload satisfies the §5.2 propagation matrix:
    ///   - REQUIRED: `trace_id`, `thread_id` (set).
    ///   - FORBIDDEN: `recommendation_id`, `source_request_id`,
    ///     `source_recommendation_id`, `surface_session_id`,
    ///     `feedback_chain_id` (all unset).
    ///
    /// `trace_id` is freshly issued; `thread_id` is the stable id
    /// captured at init. The matrix is validated locally; a
    /// violation is a programming error and silently aborts the
    /// emit (the user prompt still commits — telemetry MUST NOT
    /// break user-visible flow per the contract's silent-emission
    /// principle and `TelemetryEmitter.emit(_:_:)` non-throwing
    /// signature).
    ///
    /// The actual emit fires as a fire-and-forget `Task`; the handle
    /// is exposed via `pendingTelemetryEmit` so tests can `await` it
    /// before asserting on a sink. This mirrors the
    /// `pendingFeedbackEmit` pattern from Main A.
    private func emitChatPromptSubmit() {
        let traceID = identifierFactory.makeTraceID()
        let payload = TelemetryEventPayload(
            traceID: traceID,
            threadID: threadID
        )

        // Matrix check per §5.2. Empty violations means well-formed.
        guard TelemetryPropagationMatrix
            .violations(.chatPromptSubmit, payload)
            .isEmpty
        else {
            // Programming error: skip emit, let the prompt commit.
            return
        }

        // Main D.1: capture the issued trace_id so the
        // continuation-telemetry emit at surface return can
        // propagate the SAME trace_id per
        // `Contracts/telemetry-contract-v1.md` §3 + §5.1.
        lastIssuedTraceID = traceID

        let emitter = telemetryEmitter
        pendingTelemetryEmit = Task { @MainActor in
            await emitter.emit(.chatPromptSubmit, payload)
        }
    }

    /// Whether this build exposes the full super-app capability surfaces. In the
    /// local-first v1 only Chat + Health are enabled (`enabledSurfaces`), so
    /// suggested prompts, the welcome, and per-message replies stay within them.
    private var offersCapabilitySurfaces: Bool {
        enabledSurfaces.contains(.maps)
            || enabledSurfaces.contains(.store)
            || enabledSurfaces.contains(.ai)
    }

    /// When a prompt's intent points at a withheld surface, the chat answers
    /// on-device rather than advertising a hidden Maps/Store/AI flow or emitting
    /// a placeholder surface card. Returns the replacement reply, or `nil` when
    /// the prompt is in-scope for the enabled surfaces and the normal keyword
    /// replies apply (always `nil` when every surface is enabled).
    private func withheldSurfaceContent(for prompt: String) -> (text: String, tags: [String])? {
        guard let route = rawRoute(for: prompt),
              route != .chat,
              route != .health,
              enabledSurfaces.contains(route) == false else {
            return nil
        }
        return (
            "I'm focused on your health and on-device questions in this version. Ask me about your Apple Health trends, or how kAir keeps your data private on this device.",
            ["On-device"]
        )
    }

    private static func healthFirstSuggestedPrompts(supportsHealthData: Bool) -> [String] {
        supportsHealthData
            ? [
                "What changed most in my health today?",
                "Explain my sleep trend",
                "How does kAir keep my data private?"
            ]
            : [
                "What can kAir help me with?",
                "How does kAir keep my data private?",
                "How does on-device AI work?"
            ]
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
        "You are in kAir. I read your local Apple Health snapshot and explain it in plain language — on your device, never exported. \(dashboard.hero.summary)"
    }

    private static func welcomeMessageWithoutDashboard(supportsHealthData: Bool) -> String {
        if supportsHealthData {
            return "You are in kAir. Chat is live and runs on your device. Attach Apple Health whenever you want grounded, private health answers in this same thread."
        }
        return "You are in kAir. Chat runs on your device. This device can't attach Apple Health right now, but everything here stays local-first."
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
            return "The AI layer is designed as a routing surface: one general model for conversation, one health explainer, and one planner that decides what to surface next — all on your device."
        }

        if normalized.contains("buy") || normalized.contains("store") || normalized.contains("supplement") || normalized.contains("device") || modeID == "shop" {
            return "Store should feel curated, not loud. I would prioritize sleep and recovery tools first, then wearables, then lightweight nutrition suggestions, all anchored to what your health data actually suggests is worth watching."
        }

        if normalized.contains("privacy") || normalized.contains("local") {
            return "kAir reads Apple Health through HealthKit on-device. Your health context stays on your device — local-first and visible — and is never exported."
        }

        return "Right now your overall health status is \(dashboard.hero.band.lowercased()), and the clearest focus is \(leadingInsight(in: dashboard)?.title.lowercased() ?? "recent trends"). Ask me to unpack any of it — I'll keep the answer grounded in your local data."
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
            ? "kAir is chat-first and runs on your device. Ask me anything, and attach Apple Health when you want grounded health guidance."
            : "kAir is chat-first and runs on your device. Apple Health grounding isn't available here, but everything else stays local-first."
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
                .init(key: "Privacy", value: "On-device")
            ],
            footer: supportsHealthData
                ? "Open the Health surface to grant Apple Health access."
                : "Chat runs on your device without Apple Health."
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
