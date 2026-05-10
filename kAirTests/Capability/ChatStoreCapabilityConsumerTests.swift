//
//  ChatStoreCapabilityConsumerTests.swift
//  kAirTests
//
//  Main C integration tests: `ChatStore` is the FIRST real consumer
//  of `CapabilityRegistry`. At construction it MUST schedule a
//  `availabilitySnapshot()` call and store the result on
//  `capabilityAvailability`.
//
//  Pinned invariants per
//  Contracts/capability-registry-and-adapter-contract-v1.md:
//    - §7.3: `availabilitySnapshot()` maps each *registered* kind to
//      its current `isAvailable()` value; unregistered kinds are
//      omitted.
//    - §3.1: `.aiCompletion`, `.threadLookup`, `.localStoreLookup`
//      are the v1 shipped kinds.
//    - §3.2: the 7 reserved kinds have no v1 commitment and MUST
//      NOT appear in the default factory's snapshot.
//
//  The consumer call is real: it runs from the production `init`
//  path, not from a test-only seam. Tests `await` the resulting task
//  via `pendingCapabilityRefresh` to remove fire-and-forget races.
//

import XCTest
@testable import kAir

@MainActor
final class ChatStoreCapabilityConsumerTests: XCTestCase {

    // MARK: - Init triggers a real snapshot

    func test_init_schedulesCapabilityRefresh() async throws {
        let store = ChatStore()
        // Pin: the init kicks off a fire-and-forget refresh task.
        // (Tests that need the result `await` the task.)
        XCTAssertNotNil(store.pendingCapabilityRefresh)
    }

    func test_init_capabilityAvailabilityIsEmptyUntilTaskCompletes() throws {
        // Pre-await: the snapshot has not landed. The property
        // starts as `[:]` so views can render a "nothing known yet"
        // state without a special initialization branch.
        let store = ChatStore()
        XCTAssertTrue(store.capabilityAvailability.isEmpty)
    }

    func test_init_afterAwait_populatesAvailabilityFromDefaultRegistry() async throws {
        // The default factory registers the three §3.1 shipped
        // kinds; after the refresh task lands, the snapshot reflects
        // all three as available.
        let store = ChatStore()
        await store.pendingCapabilityRefresh?.value

        XCTAssertEqual(store.capabilityAvailability[.aiCompletion], true)
        XCTAssertEqual(store.capabilityAvailability[.threadLookup], true)
        XCTAssertEqual(store.capabilityAvailability[.localStoreLookup], true)
        XCTAssertEqual(store.capabilityAvailability.count, 3)
    }

    // MARK: - Reserved kinds omitted (§3.2 + §7.3)

    func test_init_afterAwait_omitsReservedKinds() async throws {
        let store = ChatStore()
        await store.pendingCapabilityRefresh?.value

        // §3.2 reserved kinds have no v1 commitment; the default
        // registry does not register them, so §7.3 omits them from
        // the snapshot.
        XCTAssertNil(store.capabilityAvailability[.placeSearch])
        XCTAssertNil(store.capabilityAvailability[.routePlanning])
        XCTAssertNil(store.capabilityAvailability[.musicPlayback])
        XCTAssertNil(store.capabilityAvailability[.videoPlayback])
        XCTAssertNil(store.capabilityAvailability[.healthRead])
        XCTAssertNil(store.capabilityAvailability[.healthWrite])
        XCTAssertNil(store.capabilityAvailability[.webSearch])
    }

    // MARK: - Custom registry honoured

    func test_init_withInjectedEmptyRegistry_yieldsEmptySnapshot() async throws {
        // An injected empty registry should result in an empty
        // snapshot — proving the production consumer reads from the
        // injected registry, not a singleton.
        let empty = CapabilityRegistry()
        let store = ChatStore(capabilityRegistry: empty)
        await store.pendingCapabilityRefresh?.value

        XCTAssertTrue(store.capabilityAvailability.isEmpty)
    }

    func test_init_withCustomRegistry_reflectsCustomAvailability() async throws {
        // A registry containing a single adapter that reports
        // `isAvailable() = false` should land as `[kind: false]` in
        // the snapshot.
        let registry = CapabilityRegistry()
        registry.register(UnavailableAIAdapter())
        let store = ChatStore(capabilityRegistry: registry)
        await store.pendingCapabilityRefresh?.value

        XCTAssertEqual(store.capabilityAvailability, [.aiCompletion: false])
    }

    // MARK: - refresh() can be re-run

    func test_refreshCapabilityAvailability_canBeCalledRepeatedly() async throws {
        let store = ChatStore()
        await store.pendingCapabilityRefresh?.value
        XCTAssertEqual(store.capabilityAvailability.count, 3)

        // Manually re-trigger; the new task replaces the old handle.
        store.refreshCapabilityAvailability()
        XCTAssertNotNil(store.pendingCapabilityRefresh)
        await store.pendingCapabilityRefresh?.value

        // Result is the same shape (default factory unchanged).
        XCTAssertEqual(store.capabilityAvailability.count, 3)
    }

    // MARK: - Boundary: the consumer does NOT change recommendations / behavior

    func test_init_doesNotMutateRecommendedMatches() async throws {
        // Main C MUST NOT change rail behavior. The recommendation
        // slate is unaffected by the capability snapshot.
        let store = ChatStore()
        let beforeSlate = store.recommendedMatches
        await store.pendingCapabilityRefresh?.value
        XCTAssertEqual(store.recommendedMatches, beforeSlate)
    }

    func test_init_doesNotInjectMessagesIntoSession() async throws {
        // Main C MUST NOT change transcript behavior. After
        // construction (and after the refresh resolves), the chat
        // session has no messages — same as before Main C.
        let store = ChatStore()
        await store.pendingCapabilityRefresh?.value
        XCTAssertEqual(store.session.messages.count, 0)
    }
}

// MARK: - Test double

/// A `.aiCompletion` adapter whose `isAvailable()` always returns
/// `false`. Used to verify `capabilityAvailability` reflects the
/// adapter's own answer, not a hard-coded `true`.
@MainActor
private final class UnavailableAIAdapter: CapabilityAdapter {
    static let capability: CapabilityKind = .aiCompletion

    func isAvailable() async -> Bool { false }

    func resolve(_ request: CapabilityRequest) async throws -> NormalizedResult {
        throw CapabilityError.unavailable
    }
}
