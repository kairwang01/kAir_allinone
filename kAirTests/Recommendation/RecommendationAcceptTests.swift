//
//  RecommendationAcceptTests.swift
//  kAirTests
//
//  V1 step 2: the Recommended Next positive accept bridge
//  (`ChatStore.prepareRecommendationForAccept`), per chat-home §3.5.
//
//  These tests verify the store-side data/decision boundary the
//  `RecommendedNextConsole` accept path branches on. They do NOT
//  introspect SwiftUI views.
//
//  Distinct from the dismiss/feedback path: accept emits NO `FeedbackEvent`,
//  removes only the target, writes the activation prompt to the thread, and
//  reports whether a surface should open.
//

import XCTest
@testable import kAir

@MainActor
final class RecommendationAcceptTests: XCTestCase {

    // MARK: - Existence check

    func test_accept_unknownObject_isNoOp() {
        let store = ChatStore()
        let before = store.recommendedMatches
        let beforeMessages = store.session.messages.count
        let alien = MatchingObject(
            id: "not-in-slate",
            kind: .toolEntry,
            title: "Alien",
            subtitleTokens: [],
            reasonText: nil,
            primaryCTA: "Open",
            secondaryCTA: nil
        )

        let result = store.prepareRecommendationForAccept(alien)

        XCTAssertEqual(result, .unknown)
        XCTAssertEqual(store.recommendedMatches, before)
        XCTAssertEqual(store.session.messages.count, beforeMessages)
    }

    // MARK: - Removal + sibling preservation

    func test_accept_removesTarget_siblingsPreserved() {
        let store = ChatStore()
        XCTAssertEqual(store.recommendedMatches.count, 3)
        let target = store.recommendedMatches[0]
        let siblingB = store.recommendedMatches[1]
        let siblingC = store.recommendedMatches[2]

        _ = store.prepareRecommendationForAccept(target)

        XCTAssertFalse(store.recommendedMatches.contains(target))
        XCTAssertTrue(store.recommendedMatches.contains(siblingB))
        XCTAssertTrue(store.recommendedMatches.contains(siblingC))
        XCTAssertEqual(store.recommendedMatches.count, 2)
    }

    // MARK: - Activation prompt written to thread

    func test_accept_writesActivationPromptToThread() {
        let store = ChatStore()
        let target = store.recommendedMatches[0]
        XCTAssertFalse(
            target.activationPrompt.isEmpty,
            "tripleSlate[0] fixture must carry an activation prompt"
        )

        _ = store.prepareRecommendationForAccept(target)

        let userTexts = store.session.messages
            .filter { $0.role == .user }
            .map { $0.text }
        XCTAssertTrue(userTexts.contains(target.activationPrompt))
    }

    // MARK: - No feedback emit (distinct from dismiss)

    func test_accept_emitsNoFeedbackEvent() async {
        let runtime = AcceptSpyFeedbackRuntime()
        let store = ChatStore(feedbackRuntime: runtime)
        let target = store.recommendedMatches[0]

        _ = store.prepareRecommendationForAccept(target)
        await store.pendingFeedbackEmit?.value

        XCTAssertTrue(
            runtime.emittedEvents.isEmpty,
            "accept must not emit a FeedbackEvent (that path is dismiss-only)"
        )
    }

    // MARK: - Route resolution

    func test_accept_resolvableRoute_returnsRoute() throws {
        let store = ChatStore()
        let mapsRec = try XCTUnwrap(
            store.recommendedMatches.first { $0.preferredSection == .maps }
        )

        XCTAssertEqual(store.prepareRecommendationForAccept(mapsRec), .route(.maps))
    }

    func test_accept_resolvedSearchRecommendation_returnsSearchRoute() throws {
        let searchObject = MatchingObject(
            id: "search-rec",
            kind: .searchResult,
            title: "Public result",
            subtitleTokens: ["search-api", "livePreferred"],
            reasonText: "Cited result prepared for review only.",
            primaryCTA: "Review result",
            secondaryCTA: nil,
            activationPrompt: "Review cited result: Public result",
            preferredSection: .search
        )
        let store = ChatStore(recommendationProvider: CountingRecommendationProvider([searchObject]))

        XCTAssertEqual(store.prepareRecommendationForAccept(searchObject), .route(.search))
    }

    func test_accept_unresolvableRoute_returnsThreadOnly() throws {
        let store = ChatStore()
        let noRoute = try XCTUnwrap(
            store.recommendedMatches.first { $0.preferredSection == nil }
        )

        XCTAssertEqual(store.prepareRecommendationForAccept(noRoute), .threadOnly)
    }

    // MARK: - Accept does not refresh the provider

    func test_accept_doesNotRefreshProvider() {
        let provider = CountingRecommendationProvider(RecommendationFixtures.tripleSlate)
        let store = ChatStore(recommendationProvider: provider)
        XCTAssertEqual(provider.callCount, 1, "one call at init")

        _ = store.prepareRecommendationForAccept(store.recommendedMatches[0])

        XCTAssertEqual(provider.callCount, 1, "accept must not refresh the provider")
    }

    // MARK: - Raw-submit routing is unaffected (§9 is composer-only)

    func test_accept_doesNotChangeRawSubmitRouting() {
        let store = ChatStore()
        let target = store.recommendedMatches[0]

        let routeBefore = store.route(for: "buy a recovery bundle")
        _ = store.prepareRecommendationForAccept(target)
        let routeAfter = store.route(for: "buy a recovery bundle")

        XCTAssertEqual(routeBefore, routeAfter)
    }

    func test_accept_clearsPendingMapsIntent() throws {
        let store = ChatStore()
        store.submitPrompt("I want to go to Apple Store", using: nil)
        XCTAssertEqual(store.route(for: "walk"), .maps)
        let mapsRec = try XCTUnwrap(
            store.recommendedMatches.first { $0.preferredSection == .maps }
        )

        _ = store.prepareRecommendationForAccept(mapsRec)

        XCTAssertNil(
            store.route(for: "walk"),
            "accepting a recommendation cancels stale raw Maps mode clarification"
        )
    }

    func test_accept_clearsResolvedMapsSession() throws {
        let store = ChatStore()
        store.submitPrompt("I want to go to Apple Store", using: nil)
        store.submitPrompt("walk", using: nil)
        let mapsRec = try XCTUnwrap(
            store.recommendedMatches.first { $0.preferredSection == .maps }
        )

        _ = store.prepareRecommendationForAccept(mapsRec)

        XCTAssertNil(
            store.consumeResolvedMapsSession(),
            "recommendation accept must not let handleRoute consume a stale raw Maps session"
        )
    }
}

// MARK: - Test doubles

@MainActor
private final class AcceptSpyFeedbackRuntime: FeedbackRuntime {
    var emittedEvents: [FeedbackEvent] = []

    func emit(_ event: FeedbackEvent) async throws {
        emittedEvents.append(event)
    }
}

@MainActor
private final class CountingRecommendationProvider: RecommendationProvider {
    private let matches: [MatchingObject]
    var callCount = 0

    init(_ matches: [MatchingObject]) {
        self.matches = matches
    }

    func recommendedMatches() -> [MatchingObject] {
        callCount += 1
        return matches
    }
}
