//
//  ModelRuntimeTests.swift
//  kAirTests
//
//  Reserved interface R3 (kair-architecture-redesign-v2.md §5.3): on-device
//  runtime binding seam. Coverage: bindable on-device entry, remote-gateway
//  exclusion, license gate, memory gate, budget default, and the fixture
//  conformer. Pure policy — no SDK, no model load.
//

import XCTest
@testable import kAir

final class ModelRuntimeTests: XCTestCase {

    func test_onDeviceEntry_withAcceptedLicense_isBindable() {
        let router = Self.entry(ModelCatalog.localRouterID)
        let binding = ModelRuntimeBindingPolicy.evaluate(
            entry: router,
            acceptedLicenses: [router.license],
            deviceMemoryBytes: 4_000_000_000
        )
        XCTAssertTrue(binding.isAvailable)
        XCTAssertEqual(binding.status, .unloaded)
        XCTAssertEqual(binding.runtimeFamily, router.runtimeFamily)
        XCTAssertNil(binding.unavailableReason)
    }

    func test_remoteGatewayEntry_hasNoOnDeviceRuntime() {
        let premium = Self.entry(ModelCatalog.premiumMarketID)
        let binding = ModelRuntimeBindingPolicy.evaluate(
            entry: premium,
            acceptedLicenses: [premium.license],
            deviceMemoryBytes: 4_000_000_000
        )
        XCTAssertFalse(binding.isAvailable)
        XCTAssertEqual(binding.unavailableReason, .unsupportedRuntimeFamily)
        XCTAssertNil(binding.runtimeFamily)
    }

    func test_licenseNotAccepted_isUnavailable() {
        let router = Self.entry(ModelCatalog.localRouterID)
        let binding = ModelRuntimeBindingPolicy.evaluate(
            entry: router,
            acceptedLicenses: [],
            deviceMemoryBytes: 4_000_000_000
        )
        XCTAssertFalse(binding.isAvailable)
        XCTAssertEqual(binding.unavailableReason, .licenseNotAccepted)
    }

    func test_insufficientMemory_isUnavailable() {
        let router = Self.entry(ModelCatalog.localRouterID)
        let binding = ModelRuntimeBindingPolicy.evaluate(
            entry: router,
            acceptedLicenses: [router.license],
            deviceMemoryBytes: 1
        )
        XCTAssertEqual(binding.unavailableReason, .insufficientMemory)
    }

    func test_runtimeBudget_defaultsToSwiftLMPrefill() {
        XCTAssertEqual(ModelRuntimeBudget().prefillChunkTokens, 512)
    }

    func test_fixtureRuntime_conformsToProtocol() {
        let runtime: ModelRuntime = FixtureModelRuntime(family: .coreML, status: .ready)
        XCTAssertEqual(runtime.family, .coreML)
        XCTAssertEqual(runtime.status, .ready)
    }

    private static func entry(_ id: String) -> ModelCatalogEntry {
        ModelCatalog.entry(id: id)!
    }
}
