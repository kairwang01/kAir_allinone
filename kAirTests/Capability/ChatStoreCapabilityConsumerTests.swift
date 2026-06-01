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
import SwiftUI
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

    // MARK: - AppBootstrap reserved Search propagation

    func test_bootstrapDefaultRegistryKeepsWebSearchAbsentInChatStore() async throws {
        let bootstrap = AppBootstrap()
        let store = makeStoreMirroringChatHome(bootstrap: bootstrap)
        let beforeSlate = store.recommendedMatches

        await store.pendingCapabilityRefresh?.value

        XCTAssertEqual(store.capabilityAvailability.count, 3)
        XCTAssertEqual(store.capabilityAvailability[.aiCompletion], true)
        XCTAssertEqual(store.capabilityAvailability[.threadLookup], true)
        XCTAssertEqual(store.capabilityAvailability[.localStoreLookup], true)
        XCTAssertNil(store.capabilityAvailability[.webSearch])
        XCTAssertEqual(store.recommendedMatches, beforeSlate)
        XCTAssertTrue(store.session.messages.isEmpty)
    }

    func test_bootstrapSearchOptInEnabledReachesChatStoreAvailability() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let bootstrap = AppBootstrap(reservedSearchConfiguration: configuration)
        let store = makeStoreMirroringChatHome(bootstrap: bootstrap)
        let beforeSlate = store.recommendedMatches

        await store.pendingCapabilityRefresh?.value

        XCTAssertEqual(store.capabilityAvailability.count, 4)
        XCTAssertEqual(store.capabilityAvailability[.aiCompletion], true)
        XCTAssertEqual(store.capabilityAvailability[.threadLookup], true)
        XCTAssertEqual(store.capabilityAvailability[.localStoreLookup], true)
        XCTAssertEqual(store.capabilityAvailability[.webSearch], true)
        XCTAssertEqual(store.recommendedMatches, beforeSlate)
        XCTAssertTrue(store.session.messages.isEmpty)
    }

    func test_bootstrapSearchOptInDisabledReachesChatStoreAsUnavailable() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: false
        )
        let bootstrap = AppBootstrap(reservedSearchConfiguration: configuration)
        let store = makeStoreMirroringChatHome(bootstrap: bootstrap)
        let beforeSlate = store.recommendedMatches

        await store.pendingCapabilityRefresh?.value

        XCTAssertEqual(store.capabilityAvailability.count, 4)
        XCTAssertEqual(store.capabilityAvailability[.webSearch], false)
        XCTAssertEqual(store.recommendedMatches, beforeSlate)
        XCTAssertTrue(store.session.messages.isEmpty)
    }

    // MARK: - Search availability presentation state

    func test_searchAvailabilityState_mapsDefaultDisabledAndEnabledSearchStates() async throws {
        let defaultStore = makeStoreMirroringChatHome(bootstrap: AppBootstrap())
        await defaultStore.pendingCapabilityRefresh?.value

        XCTAssertEqual(defaultStore.searchAvailabilityState, .notInBuild)
        XCTAssertEqual(defaultStore.searchAvailabilityState.statusLine, "Search not installed")

        let disabledConfiguration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: false
        )
        let disabledStore = makeStoreMirroringChatHome(
            bootstrap: AppBootstrap(reservedSearchConfiguration: disabledConfiguration)
        )
        await disabledStore.pendingCapabilityRefresh?.value

        XCTAssertEqual(disabledStore.searchAvailabilityState, .registeredUnavailable)
        XCTAssertEqual(
            disabledStore.searchAvailabilityState.statusLine,
            "Search reserved but unavailable"
        )

        let enabledConfiguration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let enabledStore = makeStoreMirroringChatHome(
            bootstrap: AppBootstrap(reservedSearchConfiguration: enabledConfiguration)
        )
        await enabledStore.pendingCapabilityRefresh?.value

        XCTAssertEqual(enabledStore.searchAvailabilityState, .available)
        XCTAssertEqual(enabledStore.searchAvailabilityState.statusLine, "Search available")
    }

    func test_searchAvailabilityState_changesOnlyAfterCapabilityRefreshLands() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let store = makeStoreMirroringChatHome(
            bootstrap: AppBootstrap(reservedSearchConfiguration: configuration)
        )

        XCTAssertEqual(store.searchAvailabilityState, .notInBuild)

        await store.pendingCapabilityRefresh?.value

        XCTAssertEqual(store.searchAvailabilityState, .available)
    }

    func test_searchAvailabilityState_readingDoesNotMutateTranscriptOrSlate() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let store = makeStoreMirroringChatHome(
            bootstrap: AppBootstrap(reservedSearchConfiguration: configuration)
        )
        await store.pendingCapabilityRefresh?.value
        let beforeSlate = store.recommendedMatches
        let beforeMessages = store.session.messages

        _ = store.searchAvailabilityState
        _ = store.searchAvailabilityState.statusLine

        XCTAssertEqual(store.recommendedMatches, beforeSlate)
        XCTAssertEqual(store.session.messages, beforeMessages)
    }

    // MARK: - Search availability display model

    func test_searchAvailabilityDisplay_mapsEveryStateToStableValues() throws {
        XCTAssertEqual(
            ChatSearchAvailabilityDisplay(state: .notInBuild),
            ChatSearchAvailabilityDisplay(
                isVisible: false,
                systemImage: "magnifyingglass",
                tone: .neutral,
                title: "Search not installed",
                statusLine: "Search not installed",
                accessibilityLabel: "Search is not installed in this build."
            )
        )
        XCTAssertEqual(
            ChatSearchAvailabilityDisplay(state: .registeredUnavailable),
            ChatSearchAvailabilityDisplay(
                isVisible: true,
                systemImage: "magnifyingglass.circle",
                tone: .warning,
                title: "Search unavailable",
                statusLine: "Search reserved but unavailable",
                accessibilityLabel: "Search is reserved but unavailable."
            )
        )
        XCTAssertEqual(
            ChatSearchAvailabilityDisplay(state: .available),
            ChatSearchAvailabilityDisplay(
                isVisible: true,
                systemImage: "magnifyingglass.circle.fill",
                tone: .positive,
                title: "Search available",
                statusLine: "Search available",
                accessibilityLabel: "Search is available."
            )
        )
    }

    func test_searchAvailabilityDisplay_defaultCopyDoesNotImplySearchCanRun() async throws {
        let store = makeStoreMirroringChatHome(bootstrap: AppBootstrap())
        await store.pendingCapabilityRefresh?.value

        let display = store.searchAvailabilityDisplay

        XCTAssertFalse(display.isVisible)
        XCTAssertEqual(display.tone, .neutral)
        XCTAssertEqual(display.statusLine, "Search not installed")
        XCTAssertFalse(display.statusLine.localizedCaseInsensitiveContains("live"))
        XCTAssertFalse(display.statusLine.localizedCaseInsensitiveContains("crawler"))
        XCTAssertFalse(display.statusLine.localizedCaseInsensitiveContains("provider"))
        XCTAssertFalse(display.accessibilityLabel.localizedCaseInsensitiveContains("available"))
    }

    func test_searchAvailabilityDisplay_readingDoesNotMutateTranscriptOrSlate() async throws {
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let store = makeStoreMirroringChatHome(
            bootstrap: AppBootstrap(reservedSearchConfiguration: configuration)
        )
        await store.pendingCapabilityRefresh?.value
        let beforeSlate = store.recommendedMatches
        let beforeMessages = store.session.messages

        _ = store.searchAvailabilityDisplay
        _ = store.searchAvailabilityDisplay.accessibilityLabel

        XCTAssertEqual(store.recommendedMatches, beforeSlate)
        XCTAssertEqual(store.session.messages, beforeMessages)
    }

    // MARK: - Search availability UI binding

    func test_searchAvailabilityIndicator_hidesDefaultNotInBuildDisplay() async throws {
        let store = makeStoreMirroringChatHome(bootstrap: AppBootstrap())
        await store.pendingCapabilityRefresh?.value

        XCTAssertNil(SearchAvailabilityIndicator.content(for: store.searchAvailabilityDisplay))
    }

    func test_searchAvailabilityIndicator_exposesVisibleRegisteredStates() throws {
        let unavailable = SearchAvailabilityIndicator.content(
            for: ChatSearchAvailabilityDisplay(state: .registeredUnavailable)
        )
        let available = SearchAvailabilityIndicator.content(
            for: ChatSearchAvailabilityDisplay(state: .available)
        )

        XCTAssertEqual(
            unavailable,
            SearchAvailabilityIndicatorContent(
                systemImage: "magnifyingglass.circle",
                statusLine: "Search reserved but unavailable",
                accessibilityLabel: "Search is reserved but unavailable.",
                tone: .warning
            )
        )
        XCTAssertEqual(
            available,
            SearchAvailabilityIndicatorContent(
                systemImage: "magnifyingglass.circle.fill",
                statusLine: "Search available",
                accessibilityLabel: "Search is available.",
                tone: .positive
            )
        )
        XCTAssertNotEqual(unavailable, available)
        XCTAssertEqual(
            SearchAvailabilityIndicator.foregroundColor(for: .warning),
            AppTheme.Palette.warning
        )
        XCTAssertEqual(
            SearchAvailabilityIndicator.foregroundColor(for: .positive),
            AppTheme.Palette.success
        )
        XCTAssertEqual(SearchAvailabilityIndicator.typography, AppTheme.Typography.chip)
    }

    func test_searchAvailabilityIndicator_bindingDoesNotMutateStateOrTelemetry() async throws {
        let emitter = InMemoryTelemetryEmitter()
        let configuration = DefaultCapabilityRegistry.makeReservedSearchConfiguration(
            isEnabled: true
        )
        let bootstrap = AppBootstrap(
            telemetryEmitter: emitter,
            reservedSearchConfiguration: configuration
        )
        let store = makeStoreMirroringChatHome(bootstrap: bootstrap)
        await store.pendingCapabilityRefresh?.value
        let beforeSlate = store.recommendedMatches
        let beforeMessages = store.session.messages
        let beforeAvailability = store.capabilityAvailability
        let beforeSection = bootstrap.currentSection
        let beforePresentedSurface = bootstrap.presentedSurface

        _ = SearchAvailabilityIndicator.content(for: store.searchAvailabilityDisplay)
        _ = SearchAvailabilityIndicator.foregroundColor(for: store.searchAvailabilityDisplay.tone)
        _ = SearchAvailabilityIndicator.backgroundColor(for: store.searchAvailabilityDisplay.tone)
        _ = SearchAvailabilityIndicator.borderColor(for: store.searchAvailabilityDisplay.tone)

        XCTAssertEqual(store.recommendedMatches, beforeSlate)
        XCTAssertEqual(store.session.messages, beforeMessages)
        XCTAssertEqual(store.capabilityAvailability, beforeAvailability)
        XCTAssertEqual(bootstrap.currentSection, beforeSection)
        XCTAssertEqual(bootstrap.presentedSurface, beforePresentedSurface)
        XCTAssertTrue(emitter.records.isEmpty)
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

    private func makeStoreMirroringChatHome(bootstrap: AppBootstrap) -> ChatStore {
        ChatStore(
            recommendationProvider: bootstrap.recommendationProvider,
            providerStatusProvider: bootstrap.providerStatusProvider,
            feedbackRuntime: bootstrap.feedbackRuntime,
            completedRecommendationHandoff: bootstrap.completedRecommendationHandoff,
            telemetryEmitter: bootstrap.telemetryEmitter,
            capabilityRegistry: bootstrap.capabilityRegistry
        )
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
