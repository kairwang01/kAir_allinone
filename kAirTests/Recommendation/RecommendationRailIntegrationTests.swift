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
}
