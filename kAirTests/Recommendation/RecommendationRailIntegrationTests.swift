//
//  RecommendationRailIntegrationTests.swift
//  kAirTests
//
//  Minimum wiring-level tests for I2.5: the rail data flows from the
//  provider through ChatStore, and the rail's resulting layoutState
//  matches the slate the provider returned.
//
//  These tests do NOT introspect SwiftUI views; they verify the
//  data-and-decision boundary that ChatHomeView's body branches on.
//

import XCTest
@testable import kAir

@MainActor
final class RecommendationRailIntegrationTests: XCTestCase {
    // MARK: - Provider stub returns the contract-shaped slate

    func test_stubProvider_returnsTripleSlate() throws {
        let provider = StubRecommendationProvider()
        let matches = provider.recommendedMatches()
        XCTAssertEqual(matches.count, 3)
    }

    func test_stubProvider_slateIsWithinSlateCap() throws {
        let matches = StubRecommendationProvider().recommendedMatches()
        XCTAssertLessThanOrEqual(matches.count, RecommendationRail.maxSlateSize)
    }

    func test_emptyProvider_returnsEmptySlate() throws {
        XCTAssertEqual(EmptyRecommendationProvider().recommendedMatches(), [])
    }

    // MARK: - ChatStore wires the provider on init

    func test_chatStore_defaultInit_populatesRecommendedMatchesFromStub() throws {
        let store = ChatStore()
        XCTAssertEqual(store.recommendedMatches.count, 3)
    }

    func test_chatStore_emptyProvider_yieldsEmptyRecommendedMatches() throws {
        let store = ChatStore(recommendationProvider: EmptyRecommendationProvider())
        XCTAssertEqual(store.recommendedMatches, [])
    }

    func test_chatStore_customProvider_isUsed() throws {
        let store = ChatStore(recommendationProvider: StubRecommendationProvider())
        XCTAssertEqual(
            store.recommendedMatches,
            RecommendationFixtures.tripleSlate
        )
    }

    // MARK: - The rail's layoutState matches the store's slate

    func test_rail_seededFromChatStore_matchesProviderSlate() throws {
        let store = ChatStore()
        let rail = RecommendationRail(objects: store.recommendedMatches)
        XCTAssertEqual(rail.renderedCardCount, 3)
        XCTAssertEqual(rail.layoutState, .triple)
    }

    func test_rail_seededFromEmptyStore_isAbsent() throws {
        let store = ChatStore(recommendationProvider: EmptyRecommendationProvider())
        let rail = RecommendationRail(objects: store.recommendedMatches)
        XCTAssertTrue(rail.isAbsent)
        XCTAssertEqual(rail.layoutState, .absent)
    }

    // MARK: - Boundary: provider stub does not modify ChatStore.session

    func test_chatStore_init_doesNotInjectMessagesIntoSession() throws {
        // The rail wiring must not pollute the chat transcript.
        // After init (before bootstrap), the session has no messages.
        let store = ChatStore()
        XCTAssertEqual(store.session.messages.count, 0)
    }

    // MARK: - Mixed slate sanity: every kind in the stub fixture is one of
    // the 9 frozen object kinds (regression pin for the contract chain)

    func test_chatStore_recommendedMatches_useFrozenObjectKinds() throws {
        let store = ChatStore()
        let kinds = Set(store.recommendedMatches.map { $0.kind })
        let allowed = Set(MatchingObjectKind.allCases)
        XCTAssertTrue(kinds.isSubset(of: allowed))
    }

    // MARK: - I3 dismiss path (negative-feedback-affordance-visual-v1 §6)

    func test_chatStore_dismiss_removesObjectFromMatches() throws {
        let store = ChatStore()
        let target = store.recommendedMatches[0]
        XCTAssertEqual(store.recommendedMatches.count, 3)

        store.dismissRecommendation(target, feedback: .dismiss)

        XCTAssertEqual(store.recommendedMatches.count, 2)
        XCTAssertFalse(store.recommendedMatches.contains(target))
    }

    func test_chatStore_dismiss_doesNotWriteToTranscript() throws {
        let store = ChatStore()
        let target = store.recommendedMatches[0]
        let beforeCount = store.session.messages.count

        store.dismissRecommendation(target, feedback: .lessLikeThis)

        // V3 §6.3 + behavior §3.4: dismiss writes nothing to transcript.
        XCTAssertEqual(store.session.messages.count, beforeCount)
    }

    func test_chatStore_dismiss_acceptsAllFiveFeedbackKinds() throws {
        for kind in MatchingFeedbackKind.allCases {
            let store = ChatStore()
            let target = store.recommendedMatches[0]
            store.dismissRecommendation(target, feedback: kind)
            XCTAssertFalse(
                store.recommendedMatches.contains(target),
                "Dismiss should remove target for feedback kind \(kind)"
            )
        }
    }

    func test_chatStore_dismiss_unknownObject_isNoOp() throws {
        let store = ChatStore()
        let beforeCount = store.recommendedMatches.count
        let alien = MatchingObject(
            id: "not-in-slate",
            kind: .toolEntry,
            title: "Alien",
            subtitleTokens: [],
            reasonText: nil,
            primaryCTA: "Open",
            secondaryCTA: nil,
            trustPills: []
        )

        store.dismissRecommendation(alien, feedback: .dismiss)

        XCTAssertEqual(store.recommendedMatches.count, beforeCount)
    }

    func test_chatStore_dismiss_onlyTargetCardRemoved_siblingsPersist() throws {
        // V3 §8 + behavior §5.3: dismissing one card leaves siblings on screen.
        let store = ChatStore()
        let target = store.recommendedMatches[1]   // middle card
        let siblingA = store.recommendedMatches[0]
        let siblingC = store.recommendedMatches[2]

        store.dismissRecommendation(target, feedback: .notInterested)

        XCTAssertTrue(store.recommendedMatches.contains(siblingA))
        XCTAssertTrue(store.recommendedMatches.contains(siblingC))
        XCTAssertFalse(store.recommendedMatches.contains(target))
    }

    func test_chatStore_dismissAllThree_railBecomesAbsent() throws {
        let store = ChatStore()
        let snapshot = store.recommendedMatches

        for object in snapshot {
            store.dismissRecommendation(object, feedback: .dismiss)
        }

        XCTAssertEqual(store.recommendedMatches.count, 0)
        let rail = RecommendationRail(objects: store.recommendedMatches)
        XCTAssertTrue(rail.isAbsent)
        XCTAssertEqual(rail.layoutState, .absent)
    }

    func test_chatStore_dismiss_layoutStateTransitions() throws {
        // Verify the rail's layoutState reflects the slate after each dismiss.
        let store = ChatStore()
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .triple)

        store.dismissRecommendation(store.recommendedMatches[0], feedback: .dismiss)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .dual)

        store.dismissRecommendation(store.recommendedMatches[0], feedback: .dismiss)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .single)

        store.dismissRecommendation(store.recommendedMatches[0], feedback: .dismiss)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .absent)
    }
}
