//
//  AppIntentRouteTests.swift
//  kAirTests
//
//  A6 App Intents route boundary tests.
//

import XCTest
@testable import kAir

@MainActor
final class AppIntentRouteTests: XCTestCase {

    func test_resolveKnownSurfaceIdentifiers_mapsToBuiltAppSections() {
        XCTAssertEqual(SurfaceRouter.resolve(identifier: "chat").section, .chat)
        XCTAssertEqual(SurfaceRouter.resolve(identifier: "maps").section, .maps)
        XCTAssertEqual(SurfaceRouter.resolve(identifier: "search").section, .search)
        XCTAssertEqual(SurfaceRouter.resolve(identifier: "ai").section, .ai)
        XCTAssertEqual(SurfaceRouter.resolve(identifier: "store").section, .store)
        XCTAssertEqual(SurfaceRouter.resolve(identifier: "health").section, .health)
    }

    func test_unknownAndUnbuiltSurfaceIdentifiers_fallBackToChat() {
        for identifier in ["music", "video", "unknown", ""] {
            let decision = SurfaceRouter.resolve(identifier: identifier)

            XCTAssertEqual(decision.section, .chat)
            XCTAssertTrue(decision.isFallback)
            XCTAssertFalse(decision.opensRemoteOrThirdParty)
        }
    }

    func test_healthRoute_isLocalOnlyAndDoesNotExposeRemoteOrThirdPartyAction() {
        let decision = SurfaceRouter.resolve(identifier: "health")

        XCTAssertEqual(decision.section, .health)
        XCTAssertEqual(decision.boundary, .localOnlySensitive)
        XCTAssertFalse(decision.opensRemoteOrThirdParty)
        XCTAssertFalse(decision.exposesHealthDataOutsideApp)
    }

    func test_searchRoute_isInAppOnlyAndDoesNotImplyCrawlerOrPartnerControl() {
        let decision = SurfaceRouter.resolve(identifier: "search")

        XCTAssertEqual(decision.section, .search)
        XCTAssertEqual(decision.boundary, .inAppOnly)
        XCTAssertFalse(decision.opensRemoteOrThirdParty)
        XCTAssertFalse(decision.exposesHealthDataOutsideApp)
    }

    func test_appIntentRequest_canBeConsumedExactlyOnce() {
        let requested = SurfaceRouter.requestFromAppIntent(
            identifier: "maps",
            postsNotification: false
        )

        XCTAssertEqual(requested.section, .maps)
        XCTAssertEqual(SurfaceRouter.consumePendingAppIntentRoute(), requested)
        XCTAssertNil(SurfaceRouter.consumePendingAppIntentRoute())
    }

    func test_applyRoute_opensExistingBootstrapSurface() {
        let bootstrap = AppBootstrap()
        let decision = SurfaceRouter.resolve(identifier: "store")

        SurfaceRouter.apply(decision, to: bootstrap)

        XCTAssertEqual(bootstrap.currentSection, .store)
        XCTAssertEqual(bootstrap.presentedSurface, .store)
        XCTAssertNotNil(bootstrap.currentSurfaceSessionID)
    }

    func test_applySearchRoute_opensReadOnlySearchSurface() {
        let bootstrap = AppBootstrap()
        let decision = SurfaceRouter.resolve(identifier: "search")

        SurfaceRouter.apply(decision, to: bootstrap)

        XCTAssertEqual(bootstrap.currentSection, .search)
        XCTAssertEqual(bootstrap.presentedSurface, .search)
        XCTAssertNotNil(bootstrap.currentSurfaceSessionID)
    }

    func test_applyChatRoute_closesExistingBootstrapSurface() {
        let bootstrap = AppBootstrap()
        SurfaceRouter.apply(SurfaceRouter.resolve(identifier: "maps"), to: bootstrap)

        SurfaceRouter.apply(SurfaceRouter.resolve(identifier: "chat"), to: bootstrap)

        XCTAssertEqual(bootstrap.currentSection, .chat)
        XCTAssertNil(bootstrap.presentedSurface)
        XCTAssertNil(bootstrap.currentSurfaceSessionID)
    }

    func test_openKAirSurfaceIntent_routesSelectedSurfaceAndPerforms() async throws {
        let intent = OpenKAirSurfaceIntent(surface: .maps)

        let decision = intent.routeDecision()
        XCTAssertEqual(decision.section, .maps)
        XCTAssertEqual(decision.source, .appIntent)
        XCTAssertFalse(decision.opensRemoteOrThirdParty)

        _ = try await intent.perform()
        _ = SurfaceRouter.consumePendingAppIntentRoute()
    }

    func test_continueChatIntent_routesChatSurfaceAndPerforms() async throws {
        let intent = ContinueChatIntent()

        let decision = intent.routeDecision()
        XCTAssertEqual(decision.section, .chat)
        XCTAssertFalse(decision.isFallback)

        _ = try await intent.perform()
        _ = SurfaceRouter.consumePendingAppIntentRoute()
    }

    func test_entityQuery_suggestsOnlyBuiltKAirOwnedSurfaces() async throws {
        let entities = try await KAirIntentEntityQuery().suggestedEntities()
        let ids = entities.map(\.id)

        XCTAssertEqual(ids, ["chat", "maps", "search", "ai", "store", "health"])
        XCTAssertFalse(ids.contains("music"))
        XCTAssertFalse(ids.contains("video"))
    }
}
