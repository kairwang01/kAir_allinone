//
//  OpenKAirSurfaceIntent.swift
//  kAir
//
//  First App Intents pass: open a kAir-owned surface only.
//

import AppIntents
import Foundation

struct OpenKAirSurfaceIntent: AppIntent {
    static var title: LocalizedStringResource = "Open kAir Surface"
    static var description = IntentDescription(
        "Open Chat, Maps, Search, AI, Store, or Health inside kAir."
    )
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Surface")
    var surface: KAirIntentEntity

    init() {
        self.surface = .chat
    }

    init(surface: KAirIntentEntity) {
        self.surface = surface
    }

    @MainActor
    func routeDecision() -> SurfaceRouteDecision {
        SurfaceRouter.resolve(identifier: surface.id, source: .appIntent)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let decision = SurfaceRouter.requestFromAppIntent(identifier: routeDecision().requestedIdentifier)
        return .result(
            dialog: IntentDialog("Opening \(decision.section.title) in kAir.")
        )
    }
}

struct KAirAppShortcutsProvider: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ContinueChatIntent(),
            phrases: [
                "Continue chat in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Continue Chat",
            systemImageName: "bubble.left.and.bubble.right"
        )
        AppShortcut(
            intent: OpenKAirSurfaceIntent(),
            phrases: [
                "Open a kAir surface in \(.applicationName)"
            ],
            shortTitle: "Open Surface",
            systemImageName: "square.grid.2x2"
        )
    }
}
