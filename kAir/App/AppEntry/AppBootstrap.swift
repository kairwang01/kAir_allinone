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

    init(
        healthStore: HealthDashboardStore? = nil,
        feedbackRuntime: FeedbackRuntime = NoOpFeedbackRuntime(),
        completedRecommendationHandoff: CompletedRecommendationHandoff = NoOpCompletedRecommendationHandoff()
    ) {
        self.healthStore = healthStore ?? HealthDashboardStore()
        self.feedbackRuntime = feedbackRuntime
        self.completedRecommendationHandoff = completedRecommendationHandoff
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
