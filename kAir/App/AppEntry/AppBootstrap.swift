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
    let capabilityRegistry: CapabilityRegistry

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

    /// Last `continuationRuntime.emit(_:)` task fired from
    /// `recordSurfaceReturn(_:)`. Tests `await` this to wait for the
    /// fire-and-forget emit to complete before asserting on a sink.
    /// Production code does NOT consume this.
    @ObservationIgnored private(set) var pendingContinuationEmit: Task<Void, Never>?

    init(
        healthStore: HealthDashboardStore? = nil,
        feedbackRuntime: FeedbackRuntime = NoOpFeedbackRuntime(),
        completedRecommendationHandoff: CompletedRecommendationHandoff = NoOpCompletedRecommendationHandoff(),
        telemetryEmitter: TelemetryEmitter = NoOpTelemetryEmitter(),
        capabilityRegistry: CapabilityRegistry? = nil,
        continuationRuntime: ContinuationRuntime = NoOpContinuationRuntime()
    ) {
        self.healthStore = healthStore ?? HealthDashboardStore()
        self.feedbackRuntime = feedbackRuntime
        self.completedRecommendationHandoff = completedRecommendationHandoff
        self.telemetryEmitter = telemetryEmitter
        self.capabilityRegistry = capabilityRegistry
            ?? DefaultCapabilityRegistry.makeWithShippedStubs()
        self.continuationRuntime = continuationRuntime
    }

    func showProfile() {
        isProfilePresented = true
    }

    func openSurface(_ section: AppSection) {
        guard section != .chat else {
            closeSurface()
            return
        }

        currentSection = section
        presentedSurface = section
    }

    func openMaps(with session: MapsRouteSession? = nil) {
        if let session {
            activeMapsSession = session
        }
        openSurface(.maps)
    }

    /// State-only surface close: resets `currentSection` and
    /// `presentedSurface` without firing a continuation event.
    ///
    /// In Main D this remains as the low-level state reset used by
    /// `recordSurfaceReturn(_:)`. Production triggers should call
    /// `recordSurfaceReturn(_:)` instead so the continuation event
    /// fires; calls to this method directly are kept for
    /// state-cleanup paths that explicitly want no event.
    func closeSurface() {
        currentSection = .chat
        presentedSurface = nil
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
    /// Per §8.3: this method does NOT emit telemetry on its own.
    /// `transcript.continuation.append` / `transcript.continuation.silent`
    /// telemetry events are out of Main D scope and will land in a
    /// future telemetry main line.
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

        closeSurface()
    }

    static var preview: AppBootstrap {
        AppBootstrap(healthStore: .preview)
    }
}
