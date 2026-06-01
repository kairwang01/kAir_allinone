//
//  SurfaceRouter.swift
//  kAir
//
//  App-owned route boundary for system entry points.
//

import Foundation

/// Source for a surface route request. A6 only uses `.appIntent`; the enum
/// exists so future URL/AppShortcut/widget entries can reuse the same router
/// without inventing another mapping table.
enum SurfaceRouteSource: String, Hashable, Sendable, CaseIterable {
    case appIntent
}

/// Execution boundary for a routed surface. App Intents may open a kAir-owned
/// surface, but they must not imply remote execution, third-party automation,
/// or Health data export.
enum SurfaceRouteBoundary: String, Hashable, Sendable, CaseIterable {
    case inAppOnly
    case localOnlySensitive
}

struct SurfaceRouteDecision: Hashable, Sendable {
    let requestedIdentifier: String?
    let section: AppSection
    let source: SurfaceRouteSource
    let boundary: SurfaceRouteBoundary
    let isFallback: Bool

    var opensRemoteOrThirdParty: Bool {
        false
    }

    var exposesHealthDataOutsideApp: Bool {
        false
    }
}

/// Single route mapping surface for external/system entry points. It maps
/// public intent identifiers to the small set of currently built kAir-owned
/// sections and falls back to Chat for unknown or unbuilt surfaces.
@MainActor
enum SurfaceRouter {
    static let routeRequestedNotification = Notification.Name("kAir.surfaceRouteRequested")

    private static var pendingAppIntentRoute: SurfaceRouteDecision?

    static func resolve(
        identifier: String?,
        source: SurfaceRouteSource = .appIntent
    ) -> SurfaceRouteDecision {
        let normalized = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = normalized.flatMap(AppSection.init(rawValue:)) ?? .chat
        let boundary: SurfaceRouteBoundary = resolved == .health
            ? .localOnlySensitive
            : .inAppOnly

        return SurfaceRouteDecision(
            requestedIdentifier: normalized,
            section: resolved,
            source: source,
            boundary: boundary,
            isFallback: resolved == .chat && normalized != AppSection.chat.rawValue
        )
    }

    @discardableResult
    static func requestFromAppIntent(
        identifier: String?,
        postsNotification: Bool = true
    ) -> SurfaceRouteDecision {
        let decision = resolve(identifier: identifier, source: .appIntent)
        pendingAppIntentRoute = decision
        if postsNotification {
            NotificationCenter.default.post(name: routeRequestedNotification, object: nil)
        }
        return decision
    }

    static func consumePendingAppIntentRoute() -> SurfaceRouteDecision? {
        let decision = pendingAppIntentRoute
        pendingAppIntentRoute = nil
        return decision
    }

    static func apply(_ decision: SurfaceRouteDecision, to bootstrap: AppBootstrap) {
        switch decision.section {
        case .chat:
            bootstrap.closeSurface()
        case .maps:
            bootstrap.openMaps()
        case .health, .ai, .search, .store:
            bootstrap.openSurface(decision.section)
        }
    }

    static func applyPendingAppIntentRoute(to bootstrap: AppBootstrap) {
        guard let decision = consumePendingAppIntentRoute() else { return }
        apply(decision, to: bootstrap)
    }
}
