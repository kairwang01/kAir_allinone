//
//  DefaultCapabilityRegistryTests.swift
//  kAirTests
//
//  Pins the §3.1 shipped-stub registration behavior of the
//  composition-root factory introduced in Main C.
//
//  Coverage:
//    - The factory returns a registry with EXACTLY the three §3.1
//      shipped kinds registered (`.aiCompletion`, `.threadLookup`,
//      `.localStoreLookup`).
//    - The factory does NOT register §3.2 reserved kinds.
//    - Each registered adapter's `Self.capability` matches the kind it
//      was registered under (envelope/registry-key invariant).
//    - The published `shippedKinds` list matches `CapabilityKind`'s
//      `isShippedInV1`.
//    - Two factory calls produce independent registries (no shared
//      state).
//

import XCTest
@testable import kAir

@MainActor
final class DefaultCapabilityRegistryTests: XCTestCase {

    // MARK: - Shipped kinds present

    func test_makeWithShippedStubs_registersAllThreeShippedKinds() async throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()

        XCTAssertNotNil(registry.adapter(for: .aiCompletion))
        XCTAssertNotNil(registry.adapter(for: .threadLookup))
        XCTAssertNotNil(registry.adapter(for: .localStoreLookup))
    }

    func test_makeWithShippedStubs_snapshotReportsThreeAvailable() async throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()
        let snapshot = await registry.availabilitySnapshot()

        XCTAssertEqual(snapshot.count, 3)
        XCTAssertEqual(snapshot[.aiCompletion], true)
        XCTAssertEqual(snapshot[.threadLookup], true)
        XCTAssertEqual(snapshot[.localStoreLookup], true)
    }

    // MARK: - Reserved kinds absent (§3.2)

    func test_makeWithShippedStubs_doesNotRegisterReservedKinds() throws {
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()

        // §3.2 reserved kinds: no v1 adapter commitment, MUST NOT be
        // registered by the default factory.
        XCTAssertNil(registry.adapter(for: .placeSearch))
        XCTAssertNil(registry.adapter(for: .routePlanning))
        XCTAssertNil(registry.adapter(for: .musicPlayback))
        XCTAssertNil(registry.adapter(for: .videoPlayback))
        XCTAssertNil(registry.adapter(for: .healthRead))
        XCTAssertNil(registry.adapter(for: .healthWrite))
        XCTAssertNil(registry.adapter(for: .webSearch))
    }

    // MARK: - Adapter / kind correspondence

    func test_makeWithShippedStubs_adaptersHaveMatchingCapabilityKey() throws {
        // §5.4 envelope invariant analog: each registered adapter's
        // `static var capability` MUST equal the key it was looked up
        // by. This pins that registration uses the right adapter for
        // each kind.
        let registry = DefaultCapabilityRegistry.makeWithShippedStubs()

        for kind in DefaultCapabilityRegistry.shippedKinds {
            let adapter = try XCTUnwrap(
                registry.adapter(for: kind),
                "missing adapter for \(kind)"
            )
            XCTAssertEqual(
                type(of: adapter).capability,
                kind,
                "adapter registered under \(kind) reports capability \(type(of: adapter).capability)"
            )
        }
    }

    // MARK: - shippedKinds list shape

    func test_shippedKinds_matchesIsShippedInV1() throws {
        // The published list of shipped kinds must equal the set of
        // CapabilityKind cases for which `isShippedInV1` is true.
        let expected = Set(CapabilityKind.allCases.filter { $0.isShippedInV1 })
        XCTAssertEqual(Set(DefaultCapabilityRegistry.shippedKinds), expected)
        // Sanity: §3.1 is exactly three kinds.
        XCTAssertEqual(DefaultCapabilityRegistry.shippedKinds.count, 3)
    }

    // MARK: - Independence

    func test_makeWithShippedStubs_returnsIndependentRegistries() throws {
        // The factory MUST NOT share state across calls. Each
        // invocation produces a fresh `CapabilityRegistry`.
        let r1 = DefaultCapabilityRegistry.makeWithShippedStubs()
        let r2 = DefaultCapabilityRegistry.makeWithShippedStubs()
        XCTAssertFalse(r1 === r2)

        // Adapters are also fresh instances (no accidental singleton
        // promotion of the stubs).
        let a1 = try XCTUnwrap(r1.adapter(for: .aiCompletion))
        let a2 = try XCTUnwrap(r2.adapter(for: .aiCompletion))
        XCTAssertFalse(a1 === a2)
    }
}
