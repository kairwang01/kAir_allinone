//
//  SurfaceGatingTests.swift
//  kAirTests
//
//  Locks the v1 surface gate: the shipped build exposes only the genuinely
//  on-device surfaces (Chat + Health); Maps/Search/Store/AI are withheld until
//  real. `openSurface` enforces the gate regardless of entry point, and the chat
//  composer/routing hides withheld surfaces. Default (all surfaces) is unchanged
//  so the rest of the suite keeps full behavior.
//

import XCTest
@testable import kAir

@MainActor
final class SurfaceGatingTests: XCTestCase {

    func test_v1EnabledSurfaces_isChatAndHealthOnly() {
        XCTAssertEqual(FeatureFlag.v1EnabledSurfaces, [.chat, .health])
    }

    func test_bootstrap_withheldSurface_doesNotPresent() {
        let bootstrap = AppBootstrap(enabledSurfaces: [.chat, .health])
        bootstrap.openSurface(.maps)
        XCTAssertNil(bootstrap.presentedSurface)      // withheld → no-op
        bootstrap.openSurface(.store)
        XCTAssertNil(bootstrap.presentedSurface)
        bootstrap.openSurface(.health)
        XCTAssertEqual(bootstrap.presentedSurface, .health)   // enabled → presents
    }

    func test_chatStore_v1Surfaces_filtersChipsAndRoutes() {
        let store = ChatStore(enabledSurfaces: [.chat, .health])
        XCTAssertEqual(store.accessories.map(\.id), ["health"])   // only Health chip
        XCTAssertEqual(store.route(for: "how is my sleep"), .health)
        XCTAssertNil(store.route(for: "buy supplements"))         // store withheld
        XCTAssertNil(store.route(for: "show me the ai model"))    // ai withheld
    }

    func test_chatStore_default_keepsEverySurface() {
        let store = ChatStore()                                   // default = all
        XCTAssertEqual(store.accessories.count, 4)
        XCTAssertEqual(store.route(for: "buy supplements"), .store)
    }
}
