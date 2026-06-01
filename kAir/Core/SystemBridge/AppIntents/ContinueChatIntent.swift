//
//  ContinueChatIntent.swift
//  kAir
//
//  First App Intents pass: continue the kAir chat surface.
//

import AppIntents
import Foundation

struct ContinueChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Continue kAir Chat"
    static var description = IntentDescription(
        "Open kAir Chat without exposing any third-party app control."
    )
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @MainActor
    func routeDecision() -> SurfaceRouteDecision {
        SurfaceRouter.resolve(identifier: KAirIntentEntity.chat.id, source: .appIntent)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let decision = SurfaceRouter.requestFromAppIntent(identifier: routeDecision().requestedIdentifier)
        return .result(
            dialog: IntentDialog("Opening \(decision.section.title) in kAir.")
        )
    }
}
