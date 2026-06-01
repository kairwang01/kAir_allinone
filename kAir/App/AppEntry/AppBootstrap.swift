//
//  AppBootstrap.swift
//  kAir
//
//  Root shell bootstrap state.
//

import Foundation
import Observation

@MainActor
@Observable
final class AppBootstrap {
    var currentSection: AppSection = .chat
    var presentedSurface: AppSection?
    var isProfilePresented = false
    var activeMapsSession: MapsRouteSession?
    let healthStore: HealthDashboardStore

    /// Recommendation source composed at the app's composition root.
    ///
    /// `ChatStore` still owns slate state and feedback mutations, but it no
    /// longer has to decide which provider seeded the first Recommended Next
    /// slate. This lets the app pass a `ProjectedRecommendationProvider` later
    /// so rendered card ids line up with provider-status sources.
    ///
    /// Defaults to `StubRecommendationProvider()` so first-run, previews, and
    /// existing tests keep the current curated triple-slate behavior.
    let recommendationProvider: RecommendationProvider

    /// Feedback runtime composed at the app's composition root.
    ///
    /// `ChatStore` does NOT decide its own runtime instance; consumers
    /// (e.g. `ChatHomeView`) read this property and thread it into
    /// `ChatStore` at construction time.
    ///
    /// Defaults to `NoOpFeedbackRuntime()` per
    /// `Contracts/UX/feedback-runtime-v1.md` §5 (UI / runtime boundary)
    /// — production builds will replace this default with a real runtime
    /// once telemetry / scorer sinks are wired (Main B onward).
    let feedbackRuntime: FeedbackRuntime

    /// Hand-off surface for recommendations the user marked
    /// `.alreadyDone`. Composed at the app's composition root for the
    /// same reason as `feedbackRuntime` — `ChatStore` does NOT decide
    /// its own handoff instance.
    ///
    /// Defaults to `NoOpCompletedRecommendationHandoff()`. Replaces
    /// the Main A stopgap (`ChatStore.completedRecommendations`)
    /// per Main A.2; the future post-return continuation runtime
    /// will swap this default once wired.
    let completedRecommendationHandoff: CompletedRecommendationHandoff

    /// Telemetry emitter composed at the app's composition root.
    ///
    /// Per `Contracts/telemetry-contract-v1.md` §1 + §10, this is the
    /// seam through which kAir emits telemetry events. Defaults to
    /// `NoOpTelemetryEmitter()` so previews / tests / first-run
    /// production builds emit nothing observable.
    ///
    /// Main B wires the FIRST real emitter consumer:
    /// `ChatStore.submit(prompt:using:)` fires
    /// `TelemetryEvent.chatPromptSubmit` per §4.1. Downstream emit
    /// sites (rail, surface, continuation, feedback) are explicitly
    /// out of Main B scope and will land via separate work lines.
    let telemetryEmitter: TelemetryEmitter

    /// Capability registry composed at the app's composition root.
    ///
    /// Per `Contracts/capability-registry-and-adapter-contract-v1.md`
    /// §7, this is the single registry per app process. The default
    /// is built by `DefaultCapabilityRegistry.makeWithShippedStubs()`
    /// so the §3.1 shipped capabilities (`.aiCompletion`,
    /// `.threadLookup`, `.localStoreLookup`) are registered out of
    /// the box.
    ///
    /// Main C wires the FIRST real consumer: `ChatStore` reads
    /// availability from this registry at construction. The §3.2
    /// reserved kinds are NOT registered here — they have no v1
    /// adapter commitment per the contract. Routing / ranking /
    /// AI-fallback decisions are out of Main C scope and live in the
    /// conversation-intent layer (separate work line).
    ///
    /// Reserved Search opt-in is explicit: callers that need `.webSearch`
    /// during experiments pass either a built `SearchCapabilityAdapter` or a
    /// Search configuration to `init`. A directly injected registry still wins
    /// and is stored as-is.
    let capabilityRegistry: CapabilityRegistry

    /// Provider access defaults composed at the app root.
    ///
    /// This is the single app-level value that carries membership tier, default
    /// region, preferred provider, metered entitlements, experimental provider
    /// enablement, unavailable providers, and cache fallback before a provider,
    /// search, or MCP request is built. It is intentionally value-only: no
    /// provider SDK, API key, server transport, crawler runtime, or purchase
    /// runtime is stored here.
    ///
    /// Defaults to `.freeLocalDefault` so first-run, previews, and tests remain
    /// iOS-local unless a composition root explicitly injects a paid/provider
    /// profile.
    let providerAccessProfile: ProviderAccessProfile

    /// Provider quota snapshot composed at the app root.
    ///
    /// This is the value-only package/cost boundary that future provider
    /// envelope factories will consume. It is deliberately stored here without
    /// being executed: `AppBootstrap` does not call provider factories, Search,
    /// MCP, runtime pipeline, or server transport. By default it is derived from
    /// `providerAccessProfile` through the A45 bridge, which keeps first-run and
    /// preview builds local-only.
    let providerQuotaSnapshot: ServerProviderQuotaSnapshot

    /// Optional provider-status source composed at the app root.
    ///
    /// `ChatStore` can derive status from its recommendation provider when no
    /// explicit source exists, but future receipt/status composition belongs
    /// here. This lets the app install `ProviderStatusSourceMultiplexer`
    /// without making `ChatStore` infer source priority.
    /// A directly injected `providerStatusProvider` is stored as-is; otherwise
    /// a non-empty `providerStatusSources` list passed to `init` is composed in
    /// caller order with first-source-wins semantics.
    ///
    /// Defaults to nil so first-run, tests, and previews keep the existing
    /// no-fake-provider-status behavior.
    let providerStatusProvider: ProviderStatusProviding?

    /// Continuation runtime composed at the app's composition root.
    ///
    /// Per `Contracts/UX/continuation-runtime-v1.md` §6 + §8.3, this
    /// is the observability seam for `ChatContinuationEvent`. The
    /// transcript projection for `renderEligible == true` is owned
    /// by `ChatStore.recordContinuation(_:)` (via the
    /// `continuationHandler` closure below). The runtime here is
    /// parallel to that projection — it's where scorer / telemetry
    /// sinks will attach in future work.
    ///
    /// Main D wires the FIRST real emit sites. Defaults to
    /// `NoOpContinuationRuntime()` so previews / tests / first-run
    /// production builds emit silently.
    let continuationRuntime: ContinuationRuntime

    /// Telemetry identifier factory composed at the app's composition
    /// root. Main D.1 uses this to issue `SurfaceSessionID` per
    /// `Contracts/telemetry-contract-v1.md` §3 (issuer = the
    /// execution surface itself on entry; in kAir's composition
    /// this is `AppBootstrap.openSurface(_:)`).
    ///
    /// `ChatStore` carries its OWN factory instance for the
    /// `TraceID` / `ThreadID` issuance path from Main B. Both
    /// bootstrap and the chat store route identifier issuance
    /// through their injected factory, which keeps generation
    /// single-sourced per factory while letting tests inject
    /// deterministic conformances at either seam.
    let identifierFactory: TelemetryIdentifierFactory

    /// Assistant text generator composed at the app root (B6).
    ///
    /// Default builds use Apple Foundation Models primary (on-device, free,
    /// private — iOS 26+) with a deterministic fallback so chat always produces
    /// a reply. Staging builds can flip `serverProvidersEnabled` to route
    /// general chat through `/v1/kair/model` and replace the baseline response
    /// in place; Health/private prompts must remain on-device.
    let textGenerator: any KAirTextGenerator

    /// Optional server account session (#13). Owns token storage + refresh.
    /// Defaults to an in-memory store so previews/tests never touch the Keychain;
    /// the production app injects a Keychain-backed manager when
    /// `FeatureFlag.serverAuthEnabled` is enabled. Unused while that flag is off.
    let authSession: KAirAuthSessionManager

    /// Server endpoint configuration (base URL). Consumed only when server
    /// features are on (`FeatureFlag.serverAuthEnabled` / `serverProvidersEnabled`).
    let serverConfiguration: KAirServerConfiguration

    /// Capability surfaces this composition may open. Defaults to every surface
    /// (so tests/previews keep full behavior); the production entry restricts it
    /// to `FeatureFlag.v1EnabledSurfaces`. `openSurface(_:)` enforces it, so any
    /// missed entry point still cannot present a withheld surface.
    let enabledSurfaces: Set<AppSection>

    /// Transcript projection sink, installed by `ChatHomeView` so
    /// `recordSurfaceReturn(_:)` can route render-eligible events
    /// back into the chat session. Per
    /// `Contracts/UX/continuation-runtime-v1.md` §8.1 projection
    /// option (b), the chat owns the projection; this closure is
    /// the one-way handoff from bootstrap to `ChatStore`.
    ///
    /// `@MainActor`-only closure. Set once by the chat view; cleared
    /// only at app teardown. Setting this to `nil` causes
    /// render-eligible events to drop silently (suitable for
    /// previews / tests that don't wire a transcript).
    @ObservationIgnored var continuationHandler: ((ChatContinuationEvent) -> Void)?

    /// Resolver that returns the chat's current `(TraceID?, ThreadID?)`
    /// pair at the moment `recordSurfaceReturn(_:)` fires. Installed
    /// by `ChatHomeView` alongside `continuationHandler` so the
    /// continuation-telemetry emit (Main D.1) can populate the §5.2
    /// propagation matrix without bootstrap holding a direct
    /// `ChatStore` reference.
    ///
    /// `TraceID?` is optional because a surface entry might happen
    /// before any prompt has been submitted (no trace_id yet); in
    /// that case the continuation telemetry emit is silently skipped
    /// (programming-error path per the §5.2 missing-required-id
    /// rule). `ThreadID?` is optional for symmetry; the chat thread
    /// id is set at `ChatStore` init, so this is non-nil in
    /// practice.
    @ObservationIgnored var surfaceTelemetryIdentifiers: (() -> (trace: TraceID?, thread: ThreadID?))?

    /// `surface_session_id` issued for the currently-presented
    /// non-chat surface, or `nil` when chat is foregrounded.
    ///
    /// Issued in `openSurface(_:)` on a `.chat` → non-chat
    /// transition; consumed by the continuation-telemetry emit in
    /// `recordSurfaceReturn(_:)`, then cleared in `closeSurface()`.
    @ObservationIgnored private(set) var currentSurfaceSessionID: SurfaceSessionID?

    /// Last `continuationRuntime.emit(_:)` task fired from
    /// `recordSurfaceReturn(_:)`. Tests `await` this to wait for the
    /// fire-and-forget emit to complete before asserting on a sink.
    /// Production code does NOT consume this.
    @ObservationIgnored private(set) var pendingContinuationEmit: Task<Void, Never>?

    /// Last `telemetryEmitter.emit(_:_:)` task fired from
    /// `recordSurfaceReturn(_:)` for the Main D.1 continuation
    /// telemetry events (`transcript.continuation.append` /
    /// `transcript.continuation.silent`). Tests `await` this to
    /// wait for the fire-and-forget emit before asserting on the
    /// `TelemetryEmitter` sink. Production code does NOT consume
    /// this.
    @ObservationIgnored private(set) var pendingContinuationTelemetryEmit: Task<Void, Never>?

    init(
        healthStore: HealthDashboardStore? = nil,
        recommendationProvider: RecommendationProvider? = nil,
        feedbackRuntime: FeedbackRuntime? = nil,
        completedRecommendationHandoff: CompletedRecommendationHandoff? = nil,
        telemetryEmitter: TelemetryEmitter? = nil,
        capabilityRegistry: CapabilityRegistry? = nil,
        reservedSearchAdapter: SearchCapabilityAdapter? = nil,
        reservedSearchConfiguration: SearchCapabilityAdapter.Configuration? = nil,
        providerAccessProfile: ProviderAccessProfile? = nil,
        providerQuotaSnapshot: ServerProviderQuotaSnapshot? = nil,
        providerStatusProvider: ProviderStatusProviding? = nil,
        providerStatusSources: [any ProviderStatusProviding] = [],
        continuationRuntime: ContinuationRuntime? = nil,
        identifierFactory: TelemetryIdentifierFactory? = nil,
        textGenerator: (any KAirTextGenerator)? = nil,
        authSession: KAirAuthSessionManager? = nil,
        serverConfiguration: KAirServerConfiguration = .default,
        enabledSurfaces: Set<AppSection> = Set(AppSection.allCases)
    ) {
        self.healthStore = healthStore ?? HealthDashboardStore()
        self.recommendationProvider = recommendationProvider ?? StubRecommendationProvider()
        self.feedbackRuntime = feedbackRuntime ?? NoOpFeedbackRuntime()
        self.completedRecommendationHandoff = completedRecommendationHandoff
            ?? NoOpCompletedRecommendationHandoff()
        self.telemetryEmitter = telemetryEmitter ?? NoOpTelemetryEmitter()
        let resolvedProviderAccessProfile = providerAccessProfile ?? .freeLocalDefault
        let resolvedProviderQuotaSnapshot = providerQuotaSnapshot ?? ServerProviderQuotaSnapshot(
            providerAccessProfile: resolvedProviderAccessProfile
        )
        self.providerAccessProfile = resolvedProviderAccessProfile
        self.providerQuotaSnapshot = resolvedProviderQuotaSnapshot
        self.capabilityRegistry = Self.makeCapabilityRegistry(
            explicitRegistry: capabilityRegistry,
            reservedSearchAdapter: reservedSearchAdapter,
            reservedSearchConfiguration: reservedSearchConfiguration,
            providerQuotaSnapshot: resolvedProviderQuotaSnapshot
        )
        if let providerStatusProvider {
            self.providerStatusProvider = providerStatusProvider
        } else if providerStatusSources.isEmpty {
            self.providerStatusProvider = nil
        } else {
            self.providerStatusProvider = ProviderStatusSourceMultiplexer(
                sources: providerStatusSources
            )
        }
        self.continuationRuntime = continuationRuntime ?? NoOpContinuationRuntime()
        self.identifierFactory = identifierFactory ?? UUIDTelemetryIdentifierFactory()
        let resolvedAuthSession = authSession ?? KAirAuthSessionManager(store: InMemoryKAirSessionStore())
        self.authSession = resolvedAuthSession
        self.serverConfiguration = serverConfiguration
        if let textGenerator {
            self.textGenerator = textGenerator
        } else if FeatureFlag.serverProvidersEnabled {
            self.textGenerator = FallbackTextGenerator(
                primary: KAirServerModelTextGenerator(
                    client: serverConfiguration.makeClient(authSession: resolvedAuthSession)
                ),
                fallback: KAirTextGeneratorFactory.makeDefault()
            )
        } else {
            self.textGenerator = KAirTextGeneratorFactory.makeDefault()
        }
        self.enabledSurfaces = enabledSurfaces
    }

    private static func makeCapabilityRegistry(
        explicitRegistry: CapabilityRegistry?,
        reservedSearchAdapter: SearchCapabilityAdapter?,
        reservedSearchConfiguration: SearchCapabilityAdapter.Configuration?,
        providerQuotaSnapshot: ServerProviderQuotaSnapshot
    ) -> CapabilityRegistry {
        if let explicitRegistry {
            return explicitRegistry
        }

        let resolvedSearchAdapter = reservedSearchAdapter ?? reservedSearchConfiguration.map {
            var configuration = $0
            configuration.providerQuotaSnapshot = providerQuotaSnapshot
            return SearchCapabilityAdapter(configuration: configuration)
        }

        return DefaultCapabilityRegistry.makeWithShippedStubs(
            reservedSearchAdapter: resolvedSearchAdapter
        )
    }

    func showProfile() {
        isProfilePresented = true
    }

    /// Builds a credentialed `/v1` API client bound to this composition's auth
    /// session. The single place views obtain a server client, keeping transport
    /// assembly at the composition root. Consumed only when `serverAuthEnabled`.
    func makeServerClient() -> KAirServerAPIClient {
        serverConfiguration.makeClient(authSession: authSession)
    }

    func openSurface(_ section: AppSection) {
        guard section != .chat else {
            closeSurface()
            return
        }

        // Withheld surfaces (see `FeatureFlag.v1EnabledSurfaces`) never present,
        // regardless of entry point (chip, gate card, App Intent, deep link).
        guard enabledSurfaces.contains(section) else { return }

        // Main D.1: when transitioning from chat to a non-chat
        // surface, issue a fresh `SurfaceSessionID` per
        // `Contracts/telemetry-contract-v1.md` §3. Re-entry to the
        // same `AppSection` while already presented produces a new
        // surface session per §3 ("a user can re-enter the same
        // recommendation_id... to begin a new surface_session_id").
        currentSurfaceSessionID = identifierFactory.makeSurfaceSessionID()
        currentSection = section
        presentedSurface = section
    }

    func openMaps(with session: MapsRouteSession? = nil) {
        if let session {
            activeMapsSession = session
        }
        openSurface(.maps)
    }

    /// State-only surface close: resets `currentSection`,
    /// `presentedSurface`, AND `currentSurfaceSessionID` without
    /// firing a continuation event.
    ///
    /// In Main D this remains as the low-level state reset used by
    /// `recordSurfaceReturn(_:)`. Production triggers should call
    /// `recordSurfaceReturn(_:)` instead so the continuation event
    /// fires; calls to this method directly are kept for
    /// state-cleanup paths that explicitly want no event.
    func closeSurface() {
        currentSection = .chat
        presentedSurface = nil
        currentSurfaceSessionID = nil
    }

    /// Main D production seam: record a continuation event for the
    /// currently-presented surface and reset state.
    ///
    /// Per `Contracts/UX/continuation-runtime-v1.md` §6, the runtime
    /// emits an event for ALL FOUR `TerminalOutcome` cases. Only
    /// `renderEligible` (true for `.completion` / `.abandon`) gates
    /// the sub-payloads and the transcript projection.
    ///
    /// Behavior:
    ///   1. Capture the surface kind from `currentSection`. If chat
    ///      is foregrounded, this is a no-op (defensive — the rec
    ///      dismiss / accept-no-entry paths from the chat surface
    ///      itself are not Main D's responsibility; they're owned
    ///      by `ChatStore.dismissRecommendation` / future
    ///      accept-no-entry detection).
    ///   2. Build the event via `ContinuationProjection.makeEvent`.
    ///   3. Validate via `ContinuationEventValidator`. A non-empty
    ///      violation list is a programming error — abort silently,
    ///      still close the surface (no event = no transcript noise
    ///      from a broken projection).
    ///   4. If `renderEligible`, call the installed
    ///      `continuationHandler` (the chat transcript projection).
    ///   5. Fire `continuationRuntime.emit(event)` as a fire-and-
    ///      forget task. Handle exposed via `pendingContinuationEmit`
    ///      for tests.
    ///   6. Reset state via `closeSurface()`.
    ///
    /// Main D.1: this method emits the §4.1 continuation telemetry
    /// event (`transcript.continuation.append` for renderEligible
    /// outcomes, `transcript.continuation.silent` otherwise) AT THE
    /// SAME CHOKEPOINT as the continuation runtime emit. No second
    /// bypass path is permitted — the §5.2 propagation matrix is
    /// validated locally before emit; a missing required id (e.g.
    /// no `trace_id` yet because no prompt has been submitted) is a
    /// programming error and silently skips the emit without
    /// blocking the continuation runtime emit or the transcript
    /// projection.
    func recordSurfaceReturn(_ outcome: TerminalOutcome) {
        let section = currentSection
        guard section != .chat,
              let surface = SurfaceKind(rawValue: section.rawValue)
        else {
            // No surface to return from — defensive guard.
            return
        }

        let event = ContinuationProjection.makeEvent(
            surface: surface,
            outcome: outcome
        )

        guard ContinuationEventValidator.validate(event).isEmpty else {
            // Programming error per §7 + §10: skip emit + skip
            // transcript projection. Still reset state.
            closeSurface()
            return
        }

        // Transcript projection (renderEligible only) per §8.1
        // projection (b). The handler is installed by `ChatHomeView`;
        // a nil handler means we drop the projection silently (no
        // crash) — appropriate for previews / tests that don't wire
        // a transcript.
        if event.renderEligible {
            continuationHandler?(event)
        }

        // Fire-and-forget runtime emit. NoOp by default; production
        // runtimes record to scorer / telemetry sinks.
        let runtime = continuationRuntime
        pendingContinuationEmit = Task { @MainActor in
            try? await runtime.emit(event)
        }

        // Main D.1: parallel telemetry emit per §4.1 + §8.3. Same
        // chokepoint, no second bypass.
        emitContinuationTelemetry(for: event)

        closeSurface()
    }

    /// Build and fire the §4.1 continuation telemetry event that
    /// mirrors the `ChatContinuationEvent` emitted via the
    /// continuation runtime.
    ///
    /// Per `Contracts/telemetry-contract-v1.md` §4.1:
    ///   - `renderEligible == true` → `transcript.continuation.append`
    ///   - `renderEligible == false` → `transcript.continuation.silent`
    ///
    /// Per §5.2, both events require `trace_id`, `thread_id`, and
    /// `surface_session_id`. Identifier sources:
    ///   - `trace_id`: the chat thread's last issued `TraceID` (set
    ///     by `ChatStore.emitChatPromptSubmit()` per Main B). Read
    ///     via the `surfaceTelemetryIdentifiers` resolver
    ///     installed by `ChatHomeView`. If no prompt has been
    ///     submitted yet, the resolver returns `nil` and this emit
    ///     is silently skipped (programming-error path; the
    ///     continuation runtime emit and the transcript projection
    ///     still fire).
    ///   - `thread_id`: the chat thread's `ThreadID` (set at
    ///     `ChatStore` init). Same resolver.
    ///   - `surface_session_id`: `currentSurfaceSessionID`, issued
    ///     in `openSurface(_:)` on the chat → surface transition.
    ///
    /// Validation runs through `TelemetryPropagationMatrix` before
    /// emit. A non-empty violation list is silently absorbed (the
    /// `TelemetryEmitter.emit(_:_:)` contract is non-throwing and
    /// telemetry MUST NOT break user-visible flow).
    private func emitContinuationTelemetry(for event: ChatContinuationEvent) {
        guard let resolver = surfaceTelemetryIdentifiers else {
            // No resolver installed — typical of previews / tests
            // that don't wire a chat store. Telemetry is silently
            // skipped; the continuation runtime emit still fires.
            return
        }
        let identifiers = resolver()

        guard let traceID = identifiers.trace,
              let threadID = identifiers.thread,
              let surfaceSessionID = currentSurfaceSessionID
        else {
            // Missing required id per §5.2 — programming error.
            // Skip emit; do NOT throw or alter other paths.
            return
        }

        let telemetryEvent: TelemetryEvent = event.renderEligible
            ? .transcriptContinuationAppend
            : .transcriptContinuationSilent

        let payload = TelemetryEventPayload(
            traceID: traceID,
            threadID: threadID,
            surfaceSessionID: surfaceSessionID
        )

        guard TelemetryPropagationMatrix
            .violations(telemetryEvent, payload)
            .isEmpty
        else {
            // Programming error per §5.2 — skip emit silently.
            return
        }

        let emitter = telemetryEmitter
        pendingContinuationTelemetryEmit = Task { @MainActor in
            await emitter.emit(telemetryEvent, payload)
        }
    }

    static var preview: AppBootstrap {
        AppBootstrap(healthStore: .preview)
    }
}
