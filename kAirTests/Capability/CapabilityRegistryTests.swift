//
//  CapabilityRegistryTests.swift
//  kAirTests
//
//  Behavior tests for the capability registry, the adapter stubs, and
//  the §5.4 envelope invariant helper, per
//  Contracts/capability-registry-and-adapter-contract-v1.md §5 and §7.
//

import XCTest
@testable import kAir

@MainActor
final class CapabilityRegistryTests: XCTestCase {
    // MARK: - Empty / lookup (§7.2)

    func test_emptyRegistry_returnsNil_forAnyKind() throws {
        let registry = CapabilityRegistry()
        XCTAssertNil(registry.adapter(for: .aiCompletion))
        XCTAssertNil(registry.adapter(for: .threadLookup))
        XCTAssertNil(registry.adapter(for: .localStoreLookup))
    }

    func test_afterRegisteringAIStub_lookupReturnsNonNil() throws {
        let registry = CapabilityRegistry()
        registry.register(StubAICompletionAdapter())
        XCTAssertNotNil(registry.adapter(for: .aiCompletion))
    }

    // MARK: - Snapshot (§7.3)

    func test_availabilitySnapshot_reportsTrueForRegisteredStubs() async throws {
        let registry = CapabilityRegistry()
        registry.register(StubAICompletionAdapter())
        registry.register(StubLocalStoreLookupAdapter())
        registry.register(StubThreadLookupAdapter())

        let snapshot = await registry.availabilitySnapshot()

        XCTAssertEqual(snapshot[.aiCompletion], true)
        XCTAssertEqual(snapshot[.localStoreLookup], true)
        XCTAssertEqual(snapshot[.threadLookup], true)
    }

    func test_availabilitySnapshot_omitsUnregisteredKinds() async throws {
        let registry = CapabilityRegistry()
        registry.register(StubAICompletionAdapter())

        let snapshot = await registry.availabilitySnapshot()

        // Registered → present
        XCTAssertNotNil(snapshot[.aiCompletion])
        // Unregistered (any §3.2 kind) → absent (§7.3)
        XCTAssertNil(snapshot[.placeSearch])
        XCTAssertNil(snapshot[.routePlanning])
        XCTAssertNil(snapshot[.musicPlayback])
        XCTAssertNil(snapshot[.videoPlayback])
        XCTAssertNil(snapshot[.healthRead])
        XCTAssertNil(snapshot[.healthWrite])
        XCTAssertNil(snapshot[.webSearch])
        // Unregistered shipped kinds → also absent
        XCTAssertNil(snapshot[.threadLookup])
        XCTAssertNil(snapshot[.localStoreLookup])
        XCTAssertEqual(snapshot.count, 1)
    }

    // MARK: - Adapter resolve produces honest envelope (§5, §8)

    func test_aiStub_resolveReturnsAISynthesizedEnvelope() async throws {
        let adapter = StubAICompletionAdapter()
        let request = CapabilityRequest(kind: .aiCompletion, inputText: "hello")
        let result = try await adapter.resolve(request)
        XCTAssertEqual(result.capability, .aiCompletion)
        XCTAssertEqual(result.source, .aiSynthesized)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(result.payload, result.capability)
        )
    }

    func test_localStoreStub_resolveReturnsLocalEnvelope() async throws {
        let adapter = StubLocalStoreLookupAdapter()
        let request = CapabilityRequest(kind: .localStoreLookup)
        let result = try await adapter.resolve(request)
        XCTAssertEqual(result.capability, .localStoreLookup)
        XCTAssertEqual(result.source, .local)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(result.payload, result.capability)
        )
    }

    func test_threadLookupStub_resolveReturnsLocalEnvelope() async throws {
        let adapter = StubThreadLookupAdapter()
        let request = CapabilityRequest(kind: .threadLookup)
        let result = try await adapter.resolve(request)
        XCTAssertEqual(result.capability, .threadLookup)
        XCTAssertEqual(result.source, .local)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(result.payload, result.capability)
        )
    }

    // MARK: - §5.4 envelope invariant helper

    func test_variantMatchesCapability_returnsTrueForMatchingPair() throws {
        let completion = AICompletion(text: "x", runtimeFamily: nil)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(
                .aiCompletion(completion: completion),
                .aiCompletion
            )
        )
        let item = LocalStoreItem(id: "i", title: "t", category: nil)
        XCTAssertTrue(
            NormalizedResult.variantMatchesCapability(
                .localStoreLookup(item: item),
                .localStoreLookup
            )
        )
    }

    func test_variantMatchesCapability_returnsFalseForMismatchedPair() throws {
        let completion = AICompletion(text: "x", runtimeFamily: nil)
        XCTAssertFalse(
            NormalizedResult.variantMatchesCapability(
                .aiCompletion(completion: completion),
                .localStoreLookup
            )
        )
        let item = LocalStoreItem(id: "i", title: "t", category: nil)
        XCTAssertFalse(
            NormalizedResult.variantMatchesCapability(
                .localStoreLookup(item: item),
                .aiCompletion
            )
        )
        let thread = ThreadReference(threadID: "x", lastTouchedAt: Date(), title: nil)
        XCTAssertFalse(
            NormalizedResult.variantMatchesCapability(
                .threadLookup(thread: thread),
                .webSearch
            )
        )
    }

    // MARK: - §7.1 duplicate registration is rejected
    //
    // The contract requires a second register(...) for the same kind to be
    // a programming error: assertion / fatal in debug; "last-write-wins is
    // NOT permitted". This test exercises the release-mode behavior — that
    // the first-registered adapter wins — which is observable without
    // crashing. The DEBUG assertionFailure path is exercised by the
    // assertion itself in debug builds; we don't assert-on-assert here
    // because XCTest cannot catch assertionFailure.

    func test_duplicateRegistration_keepsFirstRegisteredAdapter() throws {
        let registry = CapabilityRegistry()
        let first = StubAICompletionAdapter()
        registry.register(first)
        // In DEBUG this triggers assertionFailure inside register(...);
        // we guard the second call out of DEBUG so the test can run.
        #if !DEBUG
        let second = StubAICompletionAdapter()
        registry.register(second)
        XCTAssertTrue(registry.adapter(for: .aiCompletion) === first)
        #else
        // In DEBUG just confirm the first adapter is reachable; the
        // assertion path is enforced by the runtime, not asserted by
        // XCTest (which cannot catch assertionFailure).
        XCTAssertTrue(registry.adapter(for: .aiCompletion) === first)
        #endif
    }
}
