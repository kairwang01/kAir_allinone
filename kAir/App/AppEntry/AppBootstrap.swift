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

    init(
        healthStore: HealthDashboardStore? = nil,
        feedbackRuntime: FeedbackRuntime = NoOpFeedbackRuntime(),
        completedRecommendationHandoff: CompletedRecommendationHandoff = NoOpCompletedRecommendationHandoff(),
        telemetryEmitter: TelemetryEmitter = NoOpTelemetryEmitter(),
        capabilityRegistry: CapabilityRegistry? = nil
    ) {
        self.healthStore = healthStore ?? HealthDashboardStore()
        self.feedbackRuntime = feedbackRuntime
        self.completedRecommendationHandoff = completedRecommendationHandoff
        self.telemetryEmitter = telemetryEmitter
        self.capabilityRegistry = capabilityRegistry
            ?? DefaultCapabilityRegistry.makeWithShippedStubs()
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

    func closeSurface() {
        currentSection = .chat
        presentedSurface = nil
    }

    static var preview: AppBootstrap {
        AppBootstrap(healthStore: .preview)
    }
}
