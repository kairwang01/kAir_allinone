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
    //
    // Note (Main A update): with Main A wiring, `dismissRecommendation`
    // now calls `refreshRecommendedMatches()` once for the four negatives
    // per `Contracts/UX/feedback-runtime-v1.md` §6.2. The
    // `StubRecommendationProvider` returns a fixed slate and does NOT
    // respect a suppression log, so the dismissed card would re-appear
    // on refresh and break these "card stays removed" assertions. The
    // tests below use `SuppressingRecommendationProvider` to simulate
    // what a real scorer-backed provider would do (filter dismissed
    // ids on subsequent calls). Production-side suppression is a
    // separate work line per the feedback-runtime-v1.md §13
    // implementation-gap note.

    func test_chatStore_dismiss_removesObjectFromMatches() throws {
        let provider = SuppressingRecommendationProvider(
            RecommendationFixtures.tripleSlate
        )
        let store = ChatStore(recommendationProvider: provider)
        let target = store.recommendedMatches[0]
        XCTAssertEqual(store.recommendedMatches.count, 3)

        // Simulate the scorer-side suppression that production would
        // perform in response to a FeedbackEvent.
        provider.suppress(target.id)
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
            let provider = SuppressingRecommendationProvider(
                RecommendationFixtures.tripleSlate
            )
            let store = ChatStore(recommendationProvider: provider)
            let target = store.recommendedMatches[0]
            provider.suppress(target.id)
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
            secondaryCTA: nil
        )

        store.dismissRecommendation(alien, feedback: .dismiss)

        XCTAssertEqual(store.recommendedMatches.count, beforeCount)
    }

    func test_chatStore_dismiss_onlyTargetCardRemoved_siblingsPersist() throws {
        // V3 §8 + behavior §5.3: dismissing one card leaves siblings on screen.
        let provider = SuppressingRecommendationProvider(
            RecommendationFixtures.tripleSlate
        )
        let store = ChatStore(recommendationProvider: provider)
        let target = store.recommendedMatches[1]   // middle card
        let siblingA = store.recommendedMatches[0]
        let siblingC = store.recommendedMatches[2]

        provider.suppress(target.id)
        store.dismissRecommendation(target, feedback: .notInterested)

        XCTAssertTrue(store.recommendedMatches.contains(siblingA))
        XCTAssertTrue(store.recommendedMatches.contains(siblingC))
        XCTAssertFalse(store.recommendedMatches.contains(target))
    }

    func test_chatStore_dismissAllThree_railBecomesAbsent() throws {
        let provider = SuppressingRecommendationProvider(
            RecommendationFixtures.tripleSlate
        )
        let store = ChatStore(recommendationProvider: provider)
        let snapshot = store.recommendedMatches

        for object in snapshot {
            provider.suppress(object.id)
            store.dismissRecommendation(object, feedback: .dismiss)
        }

        XCTAssertEqual(store.recommendedMatches.count, 0)
        let rail = RecommendationRail(objects: store.recommendedMatches)
        XCTAssertTrue(rail.isAbsent)
        XCTAssertEqual(rail.layoutState, .absent)
    }

    func test_chatStore_dismiss_layoutStateTransitions() throws {
        // Verify the rail's layoutState reflects the slate after each dismiss.
        let provider = SuppressingRecommendationProvider(
            RecommendationFixtures.tripleSlate
        )
        let store = ChatStore(recommendationProvider: provider)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .triple)

        var current = store.recommendedMatches[0]
        provider.suppress(current.id)
        store.dismissRecommendation(current, feedback: .dismiss)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .dual)

        current = store.recommendedMatches[0]
        provider.suppress(current.id)
        store.dismissRecommendation(current, feedback: .dismiss)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .single)

        current = store.recommendedMatches[0]
        provider.suppress(current.id)
        store.dismissRecommendation(current, feedback: .dismiss)
        XCTAssertEqual(RecommendationRail(objects: store.recommendedMatches).layoutState, .absent)
    }

    // MARK: - Main A: Feedback runtime real wiring
    // (Contracts/UX/feedback-runtime-v1.md §3 envelope, §6 write timing,
    //  §4.1 .alreadyDone elevation, §7.1 transcript silence,
    //  §9.2 projection option (a) — typed FeedbackEvent is sole source of truth)

    func test_dismiss_emitsTypedFeedbackEvent() async throws {
        let runtime = SpyFeedbackRuntime()
        let store = ChatStore(feedbackRuntime: runtime)
        let target = store.recommendedMatches[0]

        store.dismissRecommendation(target, feedback: .dismiss)
        await store.pendingFeedbackEmit?.value

        XCTAssertEqual(runtime.emittedEvents.count, 1)
        let emitted = runtime.emittedEvents[0]
        XCTAssertEqual(emitted.recommendationId, target.id)
        XCTAssertEqual(emitted.feedbackKind, .dismiss)
        XCTAssertFalse(emitted.id.isEmpty)
        XCTAssertTrue(FeedbackEventValidator.validate(emitted).isEmpty)
    }

    func test_dismiss_eachKindEmitsCorrectFeedbackKind() async throws {
        for kind in MatchingFeedbackKind.allCases {
            let runtime = SpyFeedbackRuntime()
            let store = ChatStore(feedbackRuntime: runtime)
            let target = store.recommendedMatches[0]

            store.dismissRecommendation(target, feedback: kind)
            await store.pendingFeedbackEmit?.value

            XCTAssertEqual(runtime.emittedEvents.count, 1, "for \(kind)")
            XCTAssertEqual(runtime.emittedEvents[0].feedbackKind, kind)
        }
    }

    func test_dismiss_invalidEvent_doesNotEmitOrRemove() async throws {
        // Empty recommendationId triggers FeedbackEventValidator §8.1
        // (recommendationIdEmpty). The runtime MUST refuse to emit and
        // MUST NOT remove the card per §6.3 step 2.
        let runtime = SpyFeedbackRuntime()
        let store = ChatStore(feedbackRuntime: runtime)
        let beforeCount = store.recommendedMatches.count
        let bad = MatchingObject(
            id: "",
            kind: .toolEntry,
            title: "Bad",
            subtitleTokens: [],
            reasonText: nil,
            primaryCTA: "x",
            secondaryCTA: nil
        )

        store.dismissRecommendation(bad, feedback: .dismiss)
        await store.pendingFeedbackEmit?.value

        XCTAssertEqual(runtime.emittedEvents.count, 0)
        XCTAssertEqual(store.recommendedMatches.count, beforeCount)
    }

    func test_fourNegatives_eachTriggersOneRefresh() async throws {
        for kind in [
            MatchingFeedbackKind.dismiss,
            .notInterested,
            .lessLikeThis,
            .notNow
        ] {
            let provider = SpyRecommendationProvider(
                matches: RecommendationFixtures.tripleSlate
            )
            let runtime = SpyFeedbackRuntime()
            let store = ChatStore(
                recommendationProvider: provider,
                feedbackRuntime: runtime
            )
            XCTAssertEqual(provider.callCount, 1, "init call for \(kind)")

            let target = store.recommendedMatches[0]
            store.dismissRecommendation(target, feedback: kind)
            await store.pendingFeedbackEmit?.value

            XCTAssertEqual(
                provider.callCount,
                2,
                "exactly one refresh after \(kind)"
            )
        }
    }

    func test_alreadyDone_doesNotTriggerRefresh() async throws {
        let provider = SpyRecommendationProvider(
            matches: RecommendationFixtures.tripleSlate
        )
        let store = ChatStore(recommendationProvider: provider)
        XCTAssertEqual(provider.callCount, 1, "init call")

        let target = store.recommendedMatches[0]
        store.dismissRecommendation(target, feedback: .alreadyDone)
        await store.pendingFeedbackEmit?.value

        XCTAssertEqual(
            provider.callCount,
            1,
            "no refresh on .alreadyDone (post-return owns refresh)"
        )
    }

    func test_alreadyDone_recordsCompletionHandoff() async throws {
        let store = ChatStore()
        let target = store.recommendedMatches[0]
        XCTAssertTrue(store.completedRecommendations.isEmpty)

        store.dismissRecommendation(target, feedback: .alreadyDone)
        await store.pendingFeedbackEmit?.value

        XCTAssertEqual(store.completedRecommendations, [target.id])
        XCTAssertFalse(store.recommendedMatches.contains(target))
    }

    func test_fourNegatives_doNotRecordCompletionHandoff() async throws {
        for kind in [
            MatchingFeedbackKind.dismiss,
            .notInterested,
            .lessLikeThis,
            .notNow
        ] {
            let store = ChatStore()
            let target = store.recommendedMatches[0]
            store.dismissRecommendation(target, feedback: kind)
            await store.pendingFeedbackEmit?.value

            XCTAssertTrue(
                store.completedRecommendations.isEmpty,
                "completed log should be empty for \(kind)"
            )
        }
    }

    func test_allFiveKinds_writeNothingToTranscript() async throws {
        // V3 §6.3 + behavior §3.4 + feedback-runtime §7.1: feedback
        // submissions write zero records to session.messages, regardless
        // of kind.
        for kind in MatchingFeedbackKind.allCases {
            let store = ChatStore()
            let target = store.recommendedMatches[0]
            let beforeCount = store.session.messages.count

            store.dismissRecommendation(target, feedback: kind)
            await store.pendingFeedbackEmit?.value

            XCTAssertEqual(
                store.session.messages.count,
                beforeCount,
                "transcript stays silent for \(kind)"
            )
        }
    }

    func test_invalidEvent_writesNothingToTranscript() async throws {
        let store = ChatStore()
        let beforeCount = store.session.messages.count
        let bad = MatchingObject(
            id: "",
            kind: .toolEntry,
            title: "Bad",
            subtitleTokens: [],
            reasonText: nil,
            primaryCTA: "x",
            secondaryCTA: nil
        )

        store.dismissRecommendation(bad, feedback: .dismiss)
        await store.pendingFeedbackEmit?.value

        XCTAssertEqual(store.session.messages.count, beforeCount)
    }
}

// MARK: - Test doubles for Main A wiring

/// Recommendation provider that records each call to
/// `recommendedMatches()`. Used to verify §6.2's
/// "exactly one refresh per dismissal" behavior.
@MainActor
private final class SpyRecommendationProvider: RecommendationProvider {
    var matches: [MatchingObject]
    var callCount = 0

    init(matches: [MatchingObject]) {
        self.matches = matches
    }

    func recommendedMatches() -> [MatchingObject] {
        callCount += 1
        return matches
    }
}

/// `FeedbackRuntime` spy that captures every `emit(_:)` call. Used to
/// verify the typed envelope is constructed and forwarded.
@MainActor
private final class SpyFeedbackRuntime: FeedbackRuntime {
    var emittedEvents: [FeedbackEvent] = []

    func emit(_ event: FeedbackEvent) async throws {
        emittedEvents.append(event)
    }
}

/// Recommendation provider that simulates the scorer-side suppression
/// log a real provider would maintain. Tests call `suppress(_:)`
/// before `dismissRecommendation` so the subsequent
/// `refreshRecommendedMatches` returns a slate excluding the
/// dismissed card, mirroring the production semantics that
/// `feedback-runtime-v1.md` §6.2 + §13 (implementation gap) describe.
@MainActor
private final class SuppressingRecommendationProvider: RecommendationProvider {
    private var matches: [MatchingObject]

    init(_ matches: [MatchingObject]) {
        self.matches = matches
    }

    func suppress(_ id: String) {
        matches.removeAll { $0.id == id }
    }

    func recommendedMatches() -> [MatchingObject] {
        matches
    }
}
